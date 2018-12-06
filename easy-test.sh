#!/bin/bash
# Basic until loop
counter=1
until [ $counter -gt 50 ]
do
mix test
sleep 1
((counter++))
done
