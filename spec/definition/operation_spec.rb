# frozen_string_literal: true

RSpec.describe OpenapiFirst::Definition::Operation do
  let(:openapi_version) { '3.1' }

  let(:operation) do
    path_item = {
      'parameters' => [
        { 'name' => 'Accept-Version', 'in' => 'header', 'schema' => { 'type' => 'integer' } },
        { 'name' => 'utm', 'in' => 'query', 'schema' => { 'type' => 'string' } },
        { 'name' => 'pet_id', 'in' => 'path', 'schema' => { 'type' => 'string' } },
        { 'name' => 'xfactor', 'in' => 'cookie', 'schema' => { 'type' => 'string' } }
      ],
      'get' => {
        'operationId' => 'get_pet',
        'parameters' => [
          { 'name' => 'limit', 'in' => 'query', 'schema' => { 'type' => 'integer' } }
        ],
        'responses' => {
          '200' => {
            'content' => {
              'application/json' => {
                'schema' => { 'type' => 'array' }
              }
            }
          },
          'default' => {
            'description' => 'unexpected error'
          }
        }
      }
    }
    described_class.new('/pets/{pet_id}', 'get', path_item, openapi_version:)
  end

  describe '#operation_id' do
    it 'returns the operationId' do
      expect(operation.operation_id).to eq 'get_pet'
    end
  end

  describe '#query_parameters' do
    it 'returns the query parameters on path and operation level' do
      expect(operation.query_parameters.map { |p| p['name'] }).to eq %w[utm limit]
    end
  end

  describe '#query_parameters_schema' do
    it 'returns a schema' do
      expect(operation.query_parameters_schema).to be_a OpenapiFirst::Schema
    end
  end

  describe '#path_parameters' do
    it 'returns the path parameters on path and operation level' do
      expect(operation.path_parameters.map { |p| p['name'] }).to eq %w[pet_id]
    end
  end

  describe '#path_parameters_schema' do
    it 'returns a schema' do
      expect(operation.path_parameters_schema).to be_a OpenapiFirst::Schema
    end
  end

  describe '#header_parameters' do
    it 'returns the header parameters' do
      expect(operation.header_parameters.map { |p| p['name'] }).to eq %w[Accept-Version]
    end

    describe 'ignored headers' do
      # These are ignored, as described in the OpenAPI spec.
      %w[Content-Type Accept Authorization].each do |header|
        it "excludes the #{header} header" do
          path_item = {
            'parameters' => [
              { 'name' => header, 'in' => 'header', 'schema' => { 'type' => 'integer' } }
            ],
            'get' => {}
          }
          operation = described_class.new('/pets/{pet_id}', 'get', path_item, openapi_version:)
          expect(operation.header_parameters).to be_nil
        end
      end
    end
  end

  describe '#header_parameters_schema' do
    it 'returns a schema' do
      expect(operation.header_parameters_schema).to be_a OpenapiFirst::Schema
    end
  end

  describe '#cookie_parameters' do
    it 'returns cookie parameters' do
      expect(operation.cookie_parameters.map { |p| p['name'] }).to eq %w[xfactor]
    end
  end

  describe '#cookie_parameters_schema' do
    it 'returns a schema' do
      expect(operation.cookie_parameters_schema).to be_a OpenapiFirst::Schema
    end
  end

  describe '#[]' do
    it 'allows to access the resolved hash' do
      expect(operation['operationId']).to eq 'get_pet'
      expect(operation['responses'].dig('200', 'content', 'application/json', 'schema', 'type')).to eq 'array'
      expect(operation['responses'].dig('default', 'description')).to eq 'unexpected error'
    end
  end

  describe '#name' do
    it 'returns a human readable name' do
      expect(operation.name).to eq 'GET /pets/{pet_id} (get_pet)'
    end
  end

  describe '#method' do
    let(:spec) { OpenapiFirst.load('./spec/data/petstore-expanded.yaml') }

    it 'returns get' do
      expect(spec.operations.first.method).to eq 'get'
    end

    it 'returns post' do
      expect(spec.operations[1].method).to eq 'post'
    end
  end

  describe '#read?' do
    it 'returns true if write? returns false' do
      operation = OpenapiFirst::Definition::Operation.new('/', 'get', {}, openapi_version:)
      expect(operation.read?).to be true
    end

    it 'returns false if write? returns true' do
      operation = OpenapiFirst::Definition::Operation.new('/', 'post', {}, openapi_version:)
      expect(operation.read?).to be false
    end
  end

  describe 'write?' do
    %w[POST PUT PATCH DELETE].each do |http_method|
      it "returns true for #{http_method}" do
        operation = OpenapiFirst::Definition::Operation.new('/', http_method.downcase, {}, openapi_version:)
        expect(operation.write?).to be true
      end
    end

    it 'returns false for GET' do
      operation = OpenapiFirst::Definition::Operation.new('/', 'get', {}, openapi_version:)
      expect(operation.write?).to be false
    end
  end

  describe '#response_for' do
    let(:spec) { OpenapiFirst.load('./spec/data/content-types.yaml') }
    let(:operation) { spec.operations.first }

    it 'finds the matching response object for a status code' do
      response = operation.response_for(200, 'application/json')
      expect(response).to be_a OpenapiFirst::Definition::Response
      expect(response.description).to eq 'Expected response to a valid request'
    end

    it 'finds an exact match without parameter' do
      response = operation.response_for(200, 'application/json')
      expect(response.content_type).to eq 'application/json'
    end

    it 'finds an exact match with parameter' do
      response = operation.response_for(200, 'application/json; profile=custom')
      expect(response.content_type).to eq 'application/json; profile=custom'
    end

    it 'finds a match while ignoring charset' do
      response = operation.response_for(200, 'application/json; charset=UTF8')
      expect(response.content_type).to eq 'application/json'
    end

    it 'finds text/* wildcard matcher' do
      response = operation.response_for(200, 'text/markdown')
      expect(response.content_type).to eq 'text/*'
    end

    it 'finds */* wildcard matcher' do
      response = operation.response_for(200, 'application/xml')
      expect(response.content_type).to eq '*/*'
    end

    context 'when status code cannot be found' do
      let(:spec) { OpenapiFirst.load('./spec/data/petstore.yaml') }
      let(:operation) { spec.path('/pets/{petId}').operation('get') }

      it 'returns nil' do
        expect(operation.response_for(201, 'application/json')).to be_nil
      end
    end

    context 'when content type cannot be found' do
      let(:spec) { OpenapiFirst.load('./spec/data/petstore.yaml') }
      let(:operation) { spec.path('/pets/{petId}').operation('get') }

      it 'returns nil' do
        expect(operation.response_for(200, 'application/xml')).to be_nil
      end
    end

    context 'when default is defined be found' do
      let(:spec) { OpenapiFirst.load('./spec/data/petstore.yaml') }
      let(:operation) { spec.path('/pets').operation('get') }

      it 'falls back to the default' do
        result = operation.response_for(201, 'application/json')
        expect(result.description).to eq 'unexpected error'
      end
    end

    context 'when no content-type is defined' do
      let(:spec) { OpenapiFirst.load('./spec/data/content-types.yaml') }
      let(:operation) { spec.path('/without-content').operation('get') }

      it 'returns the response without content' do
        result = operation.response_for(204, 'application/json')
        expect(result.description).to eq 'no content'
      end
    end

    context 'when response object media type cannot be found' do
      let(:spec) { OpenapiFirst.load('./spec/data/petstore.yaml') }
      let(:operation) do
        path_item_object = {
          'get' => {
            'responses' => {
              '200' => {
                'content' => {
                  'application/json' => {
                    'schema' => {
                      'type' => 'object'
                    }
                  }
                }
              }
            }
          }
        }
        described_class.new('/pets', 'get', path_item_object, openapi_version: '3.1')
      end

      it 'returns nil' do
        expect(operation.response_for(200, 'application/xml')).to be_nil
      end
    end

    context 'when response content is not defined' do
      let(:operation) do
        path_item_object = {
          'get' => {
            'responses' => {
              '200' => {
                'description' => 'Blank'
              }
            }
          }
        }
        described_class.new('/pets', 'get', path_item_object, openapi_version: '3.1')
      end

      it 'returns a response without content-type' do
        response = operation.response_for(200, nil)
        expect(response.description).to eq 'Blank'
        expect(response.status).to eq 200
        expect(response.content_type).to be_nil
        expect(response.content_schema).to be_nil
      end

      it 'returns a response with unknown content-type' do
        response = operation.response_for(200, 'application/json')
        expect(response.description).to eq 'Blank'
        expect(response.status).to eq 200
        expect(response.content_type).to be_nil
        expect(response.content_schema).to be_nil
      end
    end

    context 'when response object media type is not defined' do
      let(:operation) do
        path_item_object = {
          'get' => {
            'responses' => {
              '200' => {
                'description' => 'Blank',
                'content' => {}
              }
            }
          }
        }
        described_class.new('/pets', 'get', path_item_object, openapi_version: '3.1')
      end

      it 'returns a response without schema' do
        response = operation.response_for(200, 'application/json')
        expect(response.description).to eq 'Blank'
        expect(response.status).to eq 200
        expect(response.content_type).to be_nil
        expect(response.content_schema).to be_nil
      end
    end

    context 'when response content schema is not defined' do
      let(:operation) do
        path_item_object = {
          'get' => {
            'responses' => {
              '200' => {
                'content' => {
                  'application/json' => {}
                }
              }
            }
          }
        }
        described_class.new('/pets', 'get', path_item_object, openapi_version: '3.1')
      end

      it 'returns a response with content_type, but without schema' do
        response = operation.response_for(200, 'application/json')
        expect(response.status).to eq 200
        expect(response.content_type).to eq 'application/json'
        expect(response.content_schema).to be_nil
      end
    end
  end
end
