for f in yellow_tripdata_2025-0*.csv; do
timescaledb-parallel-copy \
 --connection "host=localhost user=huber dbname=tsdb sslmode=disable" \
 --table rides \
 --file "$f" \
 --columns vendor_id,tpep_pickup_datetime,tpep_dropoff_datetime,passenger_count,trip_distance,ratecode_id,store_and_fwd_flag,pu_location_id,do_location_id,payment_type,fare_amount,extra,mta_tax,tip_amount,tolls_amount,improvement_surcharge,total_amount,congestion_surcharge,airport_fee,cbd_congestion_fee \
 --workers 4 \
 --copy-options "CSV" \
 --reporting-period 30s
done
