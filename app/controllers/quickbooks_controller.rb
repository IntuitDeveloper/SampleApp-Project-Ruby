class QuickbooksController < ApplicationController
  def index
    # Pass through stored selections similar to Java controller
  end

  def qbo_login
    service = QuickbooksOauthService.new
    begin
      result = service.authorization_url
      session[:oauth_state] = result[:state]
      redirect_to result[:url], allow_other_host: true
    rescue => e
      redirect_to root_path, error: e.message
    end
  end

  def callback
    code = params[:code]
    realm_id = params[:realmId]
    if code.blank? || realm_id.blank?
      redirect_to root_path, error: "Missing code or realmId" and return
    end
    service = QuickbooksOauthService.new
    begin
      token = service.exchange_code_for_token(code)
      access_token = token["access_token"]
      refresh_token = token["refresh_token"]
      session[:access_token] = "Bearer #{access_token}"
      session[:refresh_token] = refresh_token
      session[:realm_id] = realm_id
      redirect_to root_path, notice: "Connected to QuickBooks!"
    rescue => e
      redirect_to root_path, error: e.message
    end
  end

  def call_qbo
    begin
      access = session[:access_token]
      realm = session[:realm_id]
      raise "Please authenticate first" if access.blank? || realm.blank?
      api = QuickbooksApiService.new
      data = api.get_customers(access_token: access, realm_id: realm)
      session[:customer_map] = data["customerMap"]
      items = api.get_items(access_token: access, realm_id: realm)
      session[:items] = items["items"]
      session[:itemNames] = items["itemNames"]
      session[:itemMap] = items["itemMap"]
      if (data["customers"] || []).empty?
        redirect_to root_path, notice: "No customers found, please create at least one customer to continue: https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/customer#create-a-customer"
      else
        redirect_to root_path, success: "Loaded customers and items"
      end
    rescue => e
      redirect_to root_path, error: e.message
    end
  end

  def create_project
    customer_name = params[:customerName]
    # Prefer customerId from the form; fall back to lookup by name for backward compatibility
    customer_id = params[:customerId]
    access = session[:access_token]
    realm = session[:realm_id]
    begin
      raise "Please authenticate first" if access.blank? || realm.blank?
      if customer_id.blank?
        map = session[:customer_map] || {}
        customer_id = map.key(customer_name)
      end
      raise "Could not find customer ID for #{customer_name}" if customer_id.blank?
      api = QuickbooksApiService.new
      project = api.create_project(access_token: access, customer_name: customer_name, customer_id: customer_id)
      session[:project] = project
      # clear invoice state
      session[:invoiceId] = nil
      session[:invoiceDeepLink] = nil
      session[:invoiceProjectId] = nil
      session[:invoiceAmount] = nil
      session[:invoiceNumber] = nil
      redirect_to root_path, success: "Project created"
    rescue => e
      redirect_to root_path, error: e.message
    end
  end

  def create_invoice
    access = session[:access_token]
    realm = session[:realm_id]
    begin
      raise "Please connect first" if access.blank? || realm.blank?
      api = QuickbooksApiService.new
      result = api.create_invoice(
        access_token: access,
        realm_id: realm,
        customer_id: params[:customerId],
        item_id: params[:itemId],
        item_name: params[:itemName],
        project_id: params[:projectId],
        quantity: params[:quantity].to_i,
        amount: params[:amount].to_f,
        description: params[:description]
      )
      session[:invoiceId] = result["invoiceId"]
      session[:invoiceDeepLink] = result["deepLink"]
      session[:invoiceProjectId] = result["projectId"]
      session[:invoiceAmount] = result["amount"]
      session[:invoiceNumber] = result["docNumber"]
      redirect_to root_path, success: "Invoice created"
    rescue => e
      redirect_to root_path, error: e.message
    end
  end

  def fetch_items
    access = session[:access_token]
    realm = session[:realm_id]
    begin
      raise "Please connect first" if access.blank? || realm.blank?
      api = QuickbooksApiService.new
      items = api.get_items(access_token: access, realm_id: realm)
      session[:items] = items["items"]
      session[:itemNames] = items["itemNames"]
      session[:itemMap] = items["itemMap"]
      redirect_to root_path, success: "Items loaded"
    rescue => e
      redirect_to root_path, error: e.message
    end
  end

  def logout
    reset_session
    redirect_to root_path, notice: "Logged out"
  end

  def test_environment
    render json: {
      environment: QB_CONFIG.environment,
      baseUrl: QB_CONFIG.base_url,
      graphqlUrl: QB_CONFIG.graphql_url
    }
  end

  def force_clear_session
    reset_session
    render json: { status: "Session cleared" }
  end

  def refresh_token
    begin
      rt = session[:refresh_token]
      raise "No refresh token available" if rt.blank?
      service = QuickbooksOauthService.new
      t = service.refresh_token(rt)
      at = t["access_token"]
      session[:access_token] = "Bearer #{at}" if at
      session[:refresh_token] = t["refresh_token"] if t["refresh_token"]
      preview = at && at.size > 10 ? "#{at[0,6]}…#{at[-4,4]}" : "(updated)"
      redirect_to root_path, success: "Access token refreshed: #{preview}"
    rescue => e
      redirect_to root_path, error: e.message
    end
  end
end


