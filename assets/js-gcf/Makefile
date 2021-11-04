#!make
include .env
.PHONY: try

try:
	node try.js

zip: index.js package.json stages.js
	zip -0uo function.zip stages.js index.js package.json