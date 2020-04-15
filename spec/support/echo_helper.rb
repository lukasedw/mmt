module Helpers
  module EchoHelper
    include Cmr::Util
    def echo_fail_response(response_body, status = nil)
      status = status.nil? ? 400 : status
      # failure response bodies are XML
      Echo::Response.new(Faraday::Response.new(status: status, body: response_body, response_headers: {}))
    end
  end
end

