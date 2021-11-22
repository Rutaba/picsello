#!make
include .env
.PHONY: try

try:
	node try.js

zip: index.js package.json stages.js context.js font.js BeVietnam-Bold.ttf
	zip -0uo function.zip stages.js index.js package.json context.js font.js BeVietnam-Bold.ttf
