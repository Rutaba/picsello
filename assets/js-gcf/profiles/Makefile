#!make
include ../../../.env

run:
	node run.js

deploy:
	gcloud functions deploy process-profile-images --runtime nodejs14 --trigger-bucket=${PUBLIC_BUCKET} --min-instances=1 --entry-point=processProfileImage
