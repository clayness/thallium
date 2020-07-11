#!/usr/bin/env bash
pushd results/latest/dart >/dev/null 
while read -r -u10 W; do
  find . -name "*${W//,/-}thallium.log" -exec tail -n 1 {} \; > "thallium${W//,/-}.csv"
done 10< ../.weights
find . -name "*0.33-0.33-0.33pladapt.log" -exec tail -n 1 {} \; > pladapt.csv
popd >/dev/null
