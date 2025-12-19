# convert_parquet_to_csv.py
import glob

import pandas as pd

for parquet_file in glob.glob("*.parquet"):
    csv_file = parquet_file.replace(".parquet", ".csv")
    df = pd.read_parquet(parquet_file)
    df.to_csv(csv_file, index=False, header=False)
