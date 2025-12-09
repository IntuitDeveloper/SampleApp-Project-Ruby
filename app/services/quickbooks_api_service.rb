require "net/http"
require "json"
require "openssl"

class QuickbooksApiService
  def initialize(config: QB_CONFIG)
    @config = config
  end

  def get_customers(access_token:, realm_id:)
    raise "Access token required" if access_token.to_s.strip.empty?
    raise "Realm ID required" if realm_id.to_s.strip.empty?

    url = URI(join_url(@config.base_url, "/v3/company/#{realm_id}/query"))
    url.query = URI.encode_www_form(minorversion: @config.minor_version)

    req = Net::HTTP::Post.new(url)
    req["Authorization"] = bearer(access_token)
    req["Accept"] = "application/json"
    req["Content-Type"] = "application/text"
    req.body = "Select * from Customer where Job = false"

    res = http_request(url, req)
    body = JSON.parse(res.body)
    query = body["QueryResponse"] || {}
    customers = Array(query["Customer"]) || []
    customer_names = []
    customer_map = {}
    simple = []
    customers.each do |c|
      name = c["DisplayName"] || c["FullyQualifiedName"]
      id = c["Id"].to_s
      customer_names << name
      customer_map[id] = name
      simple << { "id" => id, "name" => name }
    end
    { "customers" => simple, "customerNames" => customer_names, "customerMap" => customer_map }
  end

  def get_items(access_token:, realm_id:)
    raise "Access token required" if access_token.to_s.strip.empty?
    raise "Realm ID required" if realm_id.to_s.strip.empty?

    url = URI(join_url(@config.base_url, "/v3/company/#{realm_id}/query"))
    url.query = URI.encode_www_form(minorversion: @config.minor_version)

    req = Net::HTTP::Post.new(url)
    req["Authorization"] = bearer(access_token)
    req["Accept"] = "application/json"
    req["Content-Type"] = "application/text"
    req.body = "Select * from Item where Active = true MAXRESULTS 10"

    res = http_request(url, req)
    body = JSON.parse(res.body)
    query = body["QueryResponse"] || {}
    items = Array(query["Item"]) || []
    item_names = []
    item_map = {}
    simple = []
    items.each do |i|
      name = i["Name"]
      id = i["Id"].to_s
      item_names << name
      item_map[id] = name
      simple << { "id" => id, "name" => name }
    end
    { "items" => simple, "itemNames" => item_names, "itemMap" => item_map }
  end

  def create_project(access_token:, customer_name:, customer_id:)
    raise "Access token required" if access_token.to_s.strip.empty?
    raise "customerName required" if customer_name.to_s.strip.empty?
    raise "customerId required" if customer_id.to_s.strip.empty?

    mutation = File.read(Rails.root.join("app", "graphql", "project.graphql"))
    variables = build_project_variables(customer_name: customer_name, customer_id: customer_id)

    if Rails.env.development?
      Rails.logger.info("[GraphQL] create_project variables: #{variables.inspect}")
    end
    payload = { query: mutation, variables: variables }
    url = URI(@config.graphql_url)
    req = Net::HTTP::Post.new(url)
    req["Authorization"] = access_token
    req["Accept"] = "application/json"
    req["Content-Type"] = "application/json"
    req.body = JSON.dump(payload)

    res = http_request(url, req)
    body = JSON.parse(res.body)
    if body["errors"]
      Rails.logger.warn("[GraphQL] errors: #{body["errors"].inspect}") if Rails.env.development?
      err = body["errors"][0] || {}
      ext = err["extensions"] || {}
      # include common fields to help debugging (code/errorCode/name/path)
      parts = []
      parts << "code=#{ext["code"]}" if ext["code"]
      parts << "errorCode=#{ext["errorCode"]}" if ext["errorCode"]
      parts << "name=#{ext["name"]}" if ext["name"]
      parts << "path=#{(err["path"] || []).join(".")}" if err["path"]
      detail = parts.empty? ? nil : " (#{parts.join(", ")})"
      msg = (err["message"] || "GraphQL error").to_s + (detail || "")
      raise msg
    end
    data = body.dig("data", "projectManagementCreateProject")
    {
      "id" => data["id"],
      "name" => data["name"],
      "description" => data["description"],
      "status" => data["status"],
      "startDate" => data["startDate"],
      "dueDate" => data["dueDate"]
    }
  end

  def create_invoice(access_token:, realm_id:, customer_id:, item_id:, item_name:, project_id:, quantity:, amount:, description: nil)
    # Note: In Java we used the SDK. Here we demonstrate a QBO v3 create Invoice REST approach for parity.
    raise "Access token required" if access_token.to_s.strip.empty?
    raise "Realm ID required" if realm_id.to_s.strip.empty?
    raise "Customer ID required" if customer_id.to_s.strip.empty?
    raise "Item ID required" if item_id.to_s.strip.empty?
    raise "Project ID required" if project_id.to_s.strip.empty?

    url = URI(join_url(@config.base_url, "/v3/company/#{realm_id}/invoice"))
    url.query = URI.encode_www_form(minorversion: @config.minor_version)

    line = {
      "Amount" => (quantity.to_f * amount.to_f),
      "DetailType" => "SalesItemLineDetail",
      "SalesItemLineDetail" => {
        "ItemRef" => { "value" => item_id, "name" => item_name },
        "Qty" => quantity.to_f
      }
    }
    line["Description"] = description if description && !description.strip.empty?

    payload = {
      "CustomerRef" => { "value" => customer_id },
      "Line" => [line],
      "ProjectRef" => { "value" => project_id }
    }

    req = Net::HTTP::Post.new(url)
    req["Authorization"] = bearer(access_token)
    req["Accept"] = "application/json"
    req["Content-Type"] = "application/json"
    req.body = JSON.dump(payload)

    res = http_request(url, req)
    body = JSON.parse(res.body)
    {
      "invoiceId" => body.dig("Invoice", "Id"),
      "deepLink" => @config.invoice_deep_link(body.dig("Invoice", "Id"), realm_id),
      "projectId" => project_id,
      "customerId" => customer_id,
      "amount" => line["Amount"],
      "docNumber" => body.dig("Invoice", "DocNumber"),
      "totalAmt" => body.dig("Invoice", "TotalAmt")
    }
  end

  private

  def http_request(url, req)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = url.scheme == "https"
    # Apply SSL settings BEFORE connecting
    if ENV["QB_SSL_INSECURE"] == "1"
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    else
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      cert_store = OpenSSL::X509::Store.new
      cert_store.set_default_paths
      cert_store.flags = 0
      http.cert_store = cert_store
      # Enforce modern TLS
      http.min_version = OpenSSL::SSL::TLS1_2_VERSION if defined?(OpenSSL::SSL::TLS1_2_VERSION)
    end
    res = http.request(req)
    if res.code.to_i == 429 || res.code.to_i >= 500
      # simple retry once
      res = http.request(req)
    end
    unless res.is_a?(Net::HTTPSuccess)
      raise "HTTP error: #{res.code} #{res.body}"
    end
    res
  end

  def bearer(token)
    token.start_with?("Bearer ") ? token : "Bearer #{token}"
  end

  def join_url(base, path)
    base = base.chomp("/")
    path = path.start_with?("/") ? path : "/#{path}"
    base + path
  end

  def build_project_variables(customer_name:, customer_id:)
    template = JSON.parse(File.read(Rails.root.join("app", "graphql", "project_variables.json")))
    t = template["template"]
    uuid = SecureRandom.uuid
    now = Time.now.utc
    future = now + 5 * 365 * 24 * 60 * 60
    fmt = "%Y-%m-%dT%H:%M:%S.%LZ"
    variables = {
      name: t["name"].gsub("{uuid}", uuid),
      description: t["description"].gsub("{customerName}", customer_name),
      startDate: now.strftime(fmt),
      dueDate: future.strftime(fmt),
      priority: t["priority"],
      pinned: t["pinned"],
      customer: { id: customer_id.to_s }
    }

    # Provide a safe default enum value; adjust if your schema differs
    variables[:status] = ENV["QB_PROJECT_DEFAULT_STATUS"].presence || "IN_PROGRESS"

    variables
  end
end


