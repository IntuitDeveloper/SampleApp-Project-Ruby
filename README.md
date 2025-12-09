# QuickBooks Sample Projects API app 

This sample code will allow you to quickly connect to QB and test our Projects API.

Requirements 
- IES QB production account 
- com.intuit.quickbooks.accounting and project-management.project scopes
- OAuth credentials 

## Requirements
- Ruby 3.2+
<!-- - Rails 8+ -->
<!-- - SQLite3 -->

## Optional 
- ngrok 

## Setup
1. Install Ruby and gems:
   - `brew install ruby`
   - `bundle install`

2. Production apps do not allow the use of localhost. If you do not have an internal non-localhost redirect url to work with this demo you can follow the steps below to get an ngrok account.

3. OptionaL: Install ngrok
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; 
      - Create an account at this link: https://dashboard.ngrok.com/get-started/setup/macos
 &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; 
      - Run this command in the terminal : `brew install ngrok`
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; 
      - Run the following command to add you authtoken to the default  `ngrok.yml configuration file` then run
   -  `ngrok config add-authtoken <TOKEN-VALUE>`
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; 
   - In the terminal run: `ngrok http 3000`for this project or replace the 3000  with the port number of your choosing
   - You should now see a url in the Forwarding section in the terminal that starts with https and forwards to a local host adddress (https://234562f900c4.ngrok-free.app -> http://localhost:3000  ). 
   - Copy that url and paste in the QB_REDIRECT_URI in your .env file with /callback at the end as well as in your App's production redirect urls section

	

## Environment variables
Change the .env-template file to .env and replace the following values before starting the server: 

- QB_CLIENT_ID
- QB_CLIENT_SECRET
- QB_REDIRECT_URI (example: https://ab4hfkjuiudf.ngrok-free.app/callback)
   - If you are using ngrok the /callback will be missing from your app. Make sure you add the /callback in your .env file and your production redirect app url section here[link] and save for this to work. This step must be done after ngrok is started in order to receive the active url. 

- QB_ENVIRONMENT : production 
   - Only production apps are available for use with this API at this time
- QB_BASE_URL (default https://quickbooks.api.intuit.com)
- QB_GRAPHQL_URL (default https://qb.api.intuit.com/graphql)
- QB_SCOPES (default: "com.intuit.quickbooks.accounting project-management.project")
- QB_MINOR_VERSION (default: 75)
- QB_DEEP_LINK_TEMPLATE (default: https://app.qbo.intuit.com/app/invoice?txnId=%s&companyId=%s)

## Start the Rails server in a seperate terminal 
- `bin/rails server -b 0.0.0.0 -p 3000`

## Running the Projects API 
Navigate to your redirect url and follow the steps on the page to connect to your QB account, choose a customer, create an invoice and assign a project. 

## Endpoints 

If you have any comments, questions or concerns please reach out to developer support [ correct title and name].

