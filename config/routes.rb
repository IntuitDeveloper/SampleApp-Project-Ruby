Rails.application.routes.draw do
  root "quickbooks#index"

  get  "/qbo-login",        to: "quickbooks#qbo_login"
  get  "/callback",         to: "quickbooks#callback"
  get  "/call-qbo",         to: "quickbooks#call_qbo"
  post "/create-project",   to: "quickbooks#create_project"
  post "/create-invoice",   to: "quickbooks#create_invoice"
  get  "/fetch-items",      to: "quickbooks#fetch_items"
  get  "/logout",           to: "quickbooks#logout"
  get  "/test-environment", to: "quickbooks#test_environment"
  get  "/force-clear-session", to: "quickbooks#force_clear_session"
  post "/refresh-token",    to: "quickbooks#refresh_token"
end


