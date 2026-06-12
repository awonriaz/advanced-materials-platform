from __future__ import annotations

# Optional Apache Spark batch job for enterprise-scale ESG/material analytics.
# Run in a Spark-enabled environment: spark-submit analytics/spark_esg_batch.py data/carbon_events.csv

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as spark_sum
import sys

input_path = sys.argv[1] if len(sys.argv) > 1 else "data/carbon_events.csv"
spark = SparkSession.builder.appName("AMSCP-ESG-Batch-Analytics").getOrCreate()
df = spark.read.option("header", True).option("inferSchema", True).csv(input_path)
summary = (
    df.groupBy("lot_id")
      .agg(
          spark_sum(col("co2e_kg")).alias("total_co2e_kg"),
          spark_sum(col("energy_kwh")).alias("total_energy_kwh"),
          spark_sum(col("water_l")).alias("total_water_l"),
          spark_sum(col("waste_kg")).alias("total_waste_kg"),
      )
)
summary.show(truncate=False)
spark.stop()