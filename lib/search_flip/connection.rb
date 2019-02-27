
module SearchFlip
  class Connection
    attr_reader :base_url

    def initialize(base_url: SearchFlip::Config[:base_url])
      @base_url = base_url
    end

    # Queries and returns the ElasticSearch version used.
    #
    # @example
    #   connection.version # => e.g. 2.4.1
    #
    # @return [String] The ElasticSearch version

    def version
      @version ||= SearchFlip::HTTPClient.get("#{base_url}/").parse["version"]["number"]
    end

    # Uses the ElasticSearch Multi Search API to execute multiple search requests
    # within a single request. Raises SearchFlip::ResponseError in case any
    # errors occur.
    #
    # @example
    #   connection.msearch [ProductIndex.match_all, CommentIndex.match_all]
    #
    # @param criterias [Array<SearchFlip::Criteria>] An array of search
    #   queries to execute in parallel
    #
    # @return [Array<SearchFlip::Response>] An array of responses

    def msearch(criterias)
      payload = criterias.flat_map do |criteria|
        [
          SearchFlip::JSON.generate(index: criteria.target.index_name_with_prefix, type: criteria.target.type_name),
          SearchFlip::JSON.generate(criteria.request)
        ]
      end

      payload = payload.join("\n")
      payload << "\n"

      raw_response =
        SearchFlip::HTTPClient
          .headers(accept: "application/json", content_type: "application/x-ndjson")
          .post("#{base_url}/_msearch", body: payload)

      raw_response.parse["responses"].map.with_index do |response, index|
        SearchFlip::Response.new(criterias[index], response)
      end
    end

    # Used to manipulate, ie add and remove index aliases. Raises an
    # SearchFlip::ResponseError in case any errors occur.
    #
    # @example
    #   connection.update_aliases(actions: [
    #     { remove: { index: "test1", alias: "alias1" }},
    #     { add: { index: "test2", alias: "alias1" }}
    #   ])
    #
    # @param payload [Hash] The raw request payload
    #
    # @return [Hash] The raw response

    def update_aliases(payload)
      SearchFlip::HTTPClient
        .headers(accept: "application/json", content_type: "application/json")
        .post("#{base_url}/_aliases", body: SearchFlip::JSON.generate(payload))
        .parse
    end

    # Fetches information about the specified index aliases. Raises
    # SearchFlip::ResponseError in case any errors occur.
    #
    # @example
    #   connection.get_aliases(alias_name: "some_alias")
    #   connection.get_aliases(index_name: "index1,index2")
    #
    # @param alias_name [String] The alias or comma separated list of alias names
    # @param index_name [String] The index or comma separated list of index names
    #
    # @return [Hash] The raw response

    def get_aliases(index_name: "*", alias_name: "*")
      res = SearchFlip::HTTPClient
        .headers(accept: "application/json", content_type: "application/json")
        .get("#{base_url}/#{index_name}/_alias/#{alias_name}")
        .parse

      Hashie::Mash.new(res)
    end

    # Returns whether or not the associated ElasticSearch alias already
    # exists.
    #
    # @example
    #   connection.alias_exists?("some_alias")
    #
    # @return [Boolean] Whether or not the alias exists

    def alias_exists?(alias_name)
      SearchFlip::HTTPClient
        .headers(accept: "application/json", content_type: "application/json")
        .get("#{base_url}/_alias/#{alias_name}")

      true
    rescue SearchFlip::ResponseError => e
      return false if e.code == 404

      raise e
    end

    # Fetches information about the specified indices. Raises
    # SearchFlip::ResponseError in case any errors occur.
    #
    # @example
    #   connection.get_indices('prefix*')
    #
    # @return [Array] The raw response

    def get_indices(name = "*")
      SearchFlip::HTTPClient
        .headers(accept: "application/json", content_type: "application/json")
        .get("#{base_url}/_cat/indices/#{name}")
        .parse
    end

    # Creates the specified index within ElasticSearch and applies index
    # settings, if specified. Raises SearchFlip::ResponseError in case any
    # errors occur.
    #
    # @param index_name [String] The index name
    # @param index_settings [Hash] The index settings
    # @return [Boolean] Returns true or raises SearchFlip::ResponseError

    def create_index(index_name, index_settings = {})
      SearchFlip::HTTPClient.put(index_url(index_name), json: index_settings)

      true
    end

    # Updates the index settings within ElasticSearch according to the index
    # settings specified. Raises SearchFlip::ResponseError in case any
    # errors occur.
    #
    # @param index_name [String] The index name to update the settings for
    # @param index_settings [Hash] The index settings
    # @return [Boolean] Returns true or raises SearchFlip::ResponseError

    def update_index_settings(index_name, index_settings)
      SearchFlip::HTTPClient.put("#{index_url(index_name)}/_settings", json: index_settings)

      true
    end

    # Fetches the index settings for the specified index from ElasticSearch.
    # Sends a GET request to index_url/_settings. Raises
    # SearchFlip::ResponseError in case any errors occur.
    #
    # @param index_name [String] The index name
    # @return [Hash] The index settings

    def get_index_settings(index_name)
      SearchFlip::HTTPClient.headers(accept: "application/json").get("#{index_url(index_name)}/_settings").parse
    end

    # Sends a refresh request to ElasticSearch. Raises
    # SearchFlip::ResponseError in case any errors occur.
    #
    # @param index_names [String, Array] The optional index names to refresh
    # @return [Boolean] Returns true or raises SearchFlip::ResponseError

    def refresh(index_names = nil)
      SearchFlip::HTTPClient.post("#{index_names ? index_url(Array(index_names).join(",")) : base_url}/_refresh", json: {})

      true
    end

    # Updates the type mapping for the specified index and type within
    # ElasticSearch according to the specified mapping. Raises
    # SearchFlip::ResponseError in case any errors occur.
    #
    # @param index_name [String] The index name
    # @param type_name [String] The type name
    # @param mapping [Hash] The mapping
    # @return [Boolean] Returns true or raises SearchFlip::ResponseError

    def update_mapping(index_name, type_name, mapping)
      SearchFlip::HTTPClient.put("#{type_url(index_name, type_name)}/_mapping", json: mapping)

      true
    end

    # Retrieves the mapping for the specified index and type from
    # ElasticSearch. Raises SearchFlip::ResponseError in case any errors occur.
    #
    # @param index_name [String] The index name
    # @param type_name [String] The type name
    # @return [Hash] The current type mapping

    def get_mapping(index_name, type_name)
      SearchFlip::HTTPClient.headers(accept: "application/json").get("#{type_url(index_name, type_name)}/_mapping").parse
    end

    # Deletes the specified index from ElasticSearch. Raises
    # SearchFlip::ResponseError in case any errors occur.
    #
    # @param index_name [String] The index name
    # @return [Boolean] Returns true or raises SearchFlip::ResponseError

    def delete_index(index_name)
      SearchFlip::HTTPClient.delete index_url(index_name)

      true
    end

    # Returns whether or not the specified index already exists.
    #
    # @param index_name [String] The index name
    # @return [Boolean] Whether or not the index exists

    def index_exists?(index_name)
      SearchFlip::HTTPClient.headers(accept: "application/json").head(index_url(index_name))

      true
    rescue SearchFlip::ResponseError => e
      return false if e.code == 404

      raise e
    end

    # Returns the full ElasticSearch type URL, ie base URL, index name with
    # prefix and type name.
    #
    # @param index_name [String] The index name
    # @param type_name [String] The type name
    # @return [String] The ElasticSearch type URL

    def type_url(index_name, type_name)
      "#{index_url(index_name)}/#{type_name}"
    end

    # Returns the ElasticSearch index URL for the specified index name, ie base
    # URL and index name with prefix.
    #
    # @param index_name [String] The index name
    # @return [String] The ElasticSearch index URL

    def index_url(index_name)
      "#{base_url}/#{index_name}"
    end
  end
end
