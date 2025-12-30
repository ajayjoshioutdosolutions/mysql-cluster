#!/bin/bash
echo "Starting Custom Benchmark (Simulated Load)"
echo "----------------------------------------"

# Read Test
echo "Test 1: Read Distribution (500 queries)"
START_TIME=$(date +%s%N)
for h in {1..500}; do
   docker exec mysql-master mysql -h proxysql -P 6033 -u app_user -papp_secret_password -e "SELECT @@hostname" -s -N >> benchmark_results.txt
done
END_TIME=$(date +%s%N)
DURATION=$((($END_TIME - $START_TIME)/1000000))
echo "Read Test Completed in ${DURATION}ms"
echo "Host Distribution:"
sort benchmark_results.txt | uniq -c

# Write Test cleanup
echo "----------------------------------------"
echo "Cleaning up..."
docker exec mysql-master mysql -h proxysql -P 6033 -u app_user -papp_secret_password -e "DROP DATABASE IF EXISTS test_db;"
rm benchmark_results.txt
echo "Done."
