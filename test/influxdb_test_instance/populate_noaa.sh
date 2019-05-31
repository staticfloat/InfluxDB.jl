#!/bin/sh

curl https://s3.amazonaws.com/noaa.water-database/NOAA_data.txt -o /tmp/NOAA_data.txt
influx -import -path=/tmp/NOAA_data.txt -precision=s -database=NOAA_water_database
rm -f /tmp/NOAA_DATA.txt
