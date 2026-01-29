#!/usr/bin/env python3

import os
import pydicom
import argparse
from datetime import datetime
import csv

def get_first_dicom(directory):
    for root, _, files in os.walk(directory):
        for f in files:
            if f.lower().endswith('.dcm'):
                return os.path.join(root, f)
    return None

def extract_fields(dicom_file):
    try:
        dcm = pydicom.dcmread(dicom_file, stop_before_pixels=True)
    except Exception:
        return "n/a", "n/a", "n/a"

    TAG_PATIENT_AGE = (0x0010, 0x1010)
    TAG_PATIENT_WEIGHT = (0x0010, 0x1030)
    TAG_PATIENT_SEX = (0x0010, 0x0040)
    TAG_STUDY_DATE = (0x0008, 0x0020)
    TAG_PATIENT_BIRTH_DATE = (0x0010, 0x0030)

    sex_element = dcm.get(TAG_PATIENT_SEX, None)
    weight_element = dcm.get(TAG_PATIENT_WEIGHT, None)
    age_element = dcm.get(TAG_PATIENT_AGE, None)

    sex = sex_element.value if sex_element else 'n/a'
    if sex == '':
        sex = 'n/a'

    weight = weight_element.value if weight_element else 'n/a'
    if weight == '':
        weight = 'n/a'
    else:
        weight = str(weight)

    if age_element and age_element.value != '':
        age_raw = str(age_element.value)
        if age_raw[-1] in ['Y', 'M', 'D']:
            age_raw = age_raw[:-1]
        try:
            age = str(int(age_raw))  # Convert to int to remove leading zeros
        except ValueError:
            age = age_raw
    else:
        study_date_element = dcm.get(TAG_STUDY_DATE, None)
        birth_date_element = dcm.get(TAG_PATIENT_BIRTH_DATE, None)
        if study_date_element and birth_date_element:
            try:
                dob = datetime.strptime(birth_date_element.value, '%Y%m%d')
                study_date = datetime.strptime(study_date_element.value, '%Y%m%d')
                age_years = study_date.year - dob.year - ((study_date.month, study_date.day) < (dob.month, dob.day))
                age = str(age_years)
            except Exception:
                age = 'n/a'
        else:
            age = 'n/a'

    return sex, weight, age

def update_participants_tsv(participants_tsv_path, subject_id, session_id, sex, weight, age):
    headers = ["participant_id", "session_id", "sex", "weight", "age"]
    rows = []

    if os.path.exists(participants_tsv_path):
        with open(participants_tsv_path, 'r', encoding='utf-8') as f:
            first_char = f.read(1)
            if first_char != '\ufeff':
                f.seek(0)
            reader = csv.DictReader(f, delimiter='\t')
            rows = list(reader)

    updated = False
    for row in rows:
        pid = row.get("participant_id", "")
        ses = row.get("session_id", "")

        if pid == subject_id:
            # Update if exact match of session_id OR if existing session_id is 'n/a' and you want to update it
            if ses == session_id or (ses == 'n/a' and session_id != 'n/a'):
                row["session_id"] = session_id  # overwrite n/a with actual session
                row["sex"] = sex
                row["weight"] = weight
                row["age"] = age
                updated = True
                break

    if not updated:
        new_row = {h: '' for h in headers}
        new_row["participant_id"] = subject_id
        new_row["session_id"] = session_id
        new_row["sex"] = sex
        new_row["weight"] = weight
        new_row["age"] = age
        rows.append(new_row)

    with open(participants_tsv_path, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=headers, delimiter='\t')
        writer.writeheader()
        for row in rows:
            clean_row = {h: row.get(h, '') for h in headers}
            writer.writerow(clean_row)

def main(dicom_path, subject_id, session_id, participants_tsv):
    dicom_file = get_first_dicom(dicom_path)
    if dicom_file:
        sex, weight, age = extract_fields(dicom_file)
        print(f"Extracted from DICOM: sex='{sex}', weight='{weight}', age='{age}'")
    else:
        sex, weight, age = 'n/a', 'n/a', 'n/a'
        print(f"No DICOM file found in {dicom_path}")

    update_participants_tsv(participants_tsv, subject_id, session_id, sex, weight, age)
    print(f"Updated {participants_tsv} for {subject_id} session {session_id} with sex='{sex}', weight='{weight}', age='{age}'")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Extract demographics from DICOM and update participants.tsv")
    parser.add_argument('--dicom_path', required=True, help='Path to subject DICOM directory')
    parser.add_argument('--subject_id', required=True, help='Subject ID (e.g. sub-001)')
    parser.add_argument('--session_id', required=True, help='Session ID (e.g. ses-001)')
    parser.add_argument('--participants_tsv', required=True, help='Path to participants.tsv file')

    args = parser.parse_args()
    main(args.dicom_path, args.subject_id, args.session_id, args.participants_tsv)
