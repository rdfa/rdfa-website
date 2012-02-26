require 'rdf/util/file'
require 'net/http'
require 'uri'

module RDF::Util
  module File
    ##
    # Override to use Patron for http and https, Kernel.open otherwise.
    #
    # @param [String] filename_or_url to open
    # @param  [Hash{Symbol => Object}] options
    # @option options [Array, String] :headers
    #   HTTP Request headers.
    # @return [IO] File stream
    # @yield [IO] File stream
    def self.open_file(filename_or_url, options = {}, &block)
      case filename_or_url.to_s
      when /^file:/
        path = filename_or_url[5..-1]
        Kernel.open(path.to_s, &block)
      when /^http/
        headers = {
          "Accept" => 'text/turtle, application/rdf+xml;q=0.8, text/plain;q=0.4, */*;q=0.1',
          #"User-Agent" => "Ruby-RDF-Distiller/#{RDF::Portal::VERSION}"
        }.merge(options[:headers] || {})
        url = ::URI.parse(filename_or_url)
        io_obj = nil
        until io_obj do
          Net::HTTP::start(url.host, url.port) do |http|
            request = Net::HTTP::Get.new(url.request_uri, headers)
            response = http.request(request)
            case response
            when Net::HTTPSuccess
              # found object
              io_obj = StringIO.new(response.body)
              io_obj.instance_variable_set(:@resp, response)
            when Net::HTTPRedirection
              # Follow redirection
              url = ::URI.parse(response["Location"])
            else
              raise IOError, "Failed to open #{filename_or_url}: #{response.msg}(#{response.value})"
            end
          end
        end
        def io_obj.content_type
          @resp.content_type
        end
        def io_obj.status
          @resp.value
        end
        if block_given?
          begin
            block.call(io_obj)
          ensure
            io_obj.close
          end
        else
          io_obj
        end
      else
        Kernel.open(filename_or_url.to_s, &block)
      end
    end
  end
end
