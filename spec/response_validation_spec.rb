# frozen_string_literal: true

require_relative 'spec_helper'
require 'rack'
require 'rack/test'
require 'openapi_first'

RSpec.describe OpenapiFirst::ResponseValidation do
  include Rack::Test::Methods

  let(:app) do
    res = response
    definition = spec
    Rack::Builder.app do
      use OpenapiFirst::Middlewares::ResponseValidation, spec: definition
      use Rack::Lint
      run ->(_env) { res.finish }
    end
  end

  let(:spec) { './spec/data/petstore.yaml' }
  let(:response_body) { json_dump([{ id: 42, name: 'hans' }]) }
  let(:status) { 200 }
  let(:headers) do
    { Rack::CONTENT_TYPE => 'application/json', 'X-HEAD' => '/api/next-page' }
  end
  let(:response) { Rack::Response.new(response_body, status, headers) }

  it 'adds request to env ' do
    get '/pets'

    expect(last_request.env[OpenapiFirst::REQUEST]).to be_a OpenapiFirst::RuntimeRequest
  end

  context 'with a valid response' do
    it 'returns no errors' do
      get '/pets'

      expect(last_response.status).to eq 200
      expect(last_response.body).to eq response_body
    end
  end

  context 'without content-type header' do
    let(:headers) do
      { 'X-HEAD' => '/api/next-page' }
    end

    it 'returns an error' do
      expect do
        get '/pets'
      end.to raise_error OpenapiFirst::ResponseInvalidError,
                         "Response header is invalid: Content-Type for 'GET /pets (listPets)' must not be empty"
    end
  end

  context 'with 204 no content response' do
    let(:spec) { './spec/data/no-content.yaml' }
    let(:status) { 204 }

    let(:headers) do
      { 'X-HEAD' => '/api/next-page' }
    end

    it 'does not check the content or content-type' do
      delete '/pets/12'
      expect(last_response.status).to eq 204
    end
  end

  context 'when operation does not specify content-type' do
    let(:spec) { './spec/data/no-content.yaml' }
    let(:status) { 423 }

    context 'with any content-type' do
      let(:headers) do
        { Rack::CONTENT_TYPE => 'application/hal+json' }
      end

      it 'passes' do
        get '/pets/12'
        expect(last_response.status).to eq status
      end
    end

    context 'with an empty content-type' do
      # App without Rack::Lint, because it would raise an error about the empty content-type
      let(:app) do
        res = response
        definition = spec
        Rack::Builder.app do
          use OpenapiFirst::Middlewares::ResponseValidation, spec: definition
          run ->(_env) { res.finish }
        end
      end

      let(:headers) do
        { Rack::CONTENT_TYPE => nil }
      end

      it 'allows an empty content-type' do
        get '/pets/12'
        expect(last_response.status).to eq status
      end
    end
  end

  context 'with an unkown route' do
    it 'skips response validation' do
      get '/unknown'
      expect(last_response.status).to eq 200
    end
  end

  context 'with unknown status' do
    let(:status) { 407 }

    specify do
      expect do
        get '/pets/42'
      end.to raise_error OpenapiFirst::ResponseNotFoundError
    end
  end

  context 'with a XX wildcard response status' do
    let(:spec) { './spec/data/response-code-wildcard.yaml' }
    let(:response_body) { json_dump({}) }

    context 'when 4XX (upcase) is expected and 404 is sent' do
      let(:status) { 404 }

      it 'does not raise an error' do
        post '/test', json_dump({})
        expect(last_response.status).to eq 404
      end
    end

    context 'when 2xx (downcase, non-default) is expected and 205 is sent' do
      let(:status) { 205 }

      it 'does not raise an error' do
        post '/test', json_dump({})
        expect(last_response.status).to eq 205
      end
    end

    context 'when 4xx is expected and 302 is sent' do
      let(:status) { 302 }

      it 'finds the "default" response and raises an error' do
        expect do
          post '/test', json_dump({})
        end.to raise_error OpenapiFirst::ResponseInvalidError
      end
    end
  end

  context 'with invalid response body' do
    let(:response_body) do
      json_dump([
                  { name: 'hans' },
                  { id: '2', name: 'Voldemort' }
                ])
    end

    it 'raises ResponseBodyInvalidError' do
      expect do
        get '/pets/42'
      end.to raise_error OpenapiFirst::ResponseInvalidError
    end
  end

  context 'with a writeOnly field' do
    let(:spec) { './spec/data/writeonly.yaml' }
    let(:status) { 201 }

    context 'when field is sent in the response body' do
      let(:response_body) do
        json_dump({ name: 'hans', password: 'admin' })
      end

      it 'raises an error' do
        expect do
          post '/test', json_dump({ name: 'hans', password: 'admin' })
        end.to raise_error OpenapiFirst::ResponseInvalidError
      end
    end
  end

  context 'with a required readOnly field' do
    let(:spec) { './spec/data/readonly.yaml' }

    let(:response_body) do
      json_dump({ name: 'hans' })
    end

    it 'raises an error if the readOnly field is missing' do
      expect do
        get '/test/42'
      end.to raise_error OpenapiFirst::ResponseInvalidError
    end

    context 'when the readOnly field is valid' do
      let(:response_body) do
        json_dump({ id: '42', name: 'hans' })
      end

      it 'does not raise an error' do
        get '/test/42'
        expect(last_response.status).to eq 200
      end
    end
  end

  context 'with a required nullable field' do
    let(:spec) { './spec/data/nullable.yaml' }

    context 'when the field is missing' do
      let(:response_body) do
        json_dump({})
      end

      it 'raises an error' do
        expect do
          get '/test'
        end.to raise_error OpenapiFirst::ResponseInvalidError
      end
    end

    context 'when the field is nil' do
      let(:response_body) do
        json_dump({ name: nil })
      end

      it 'does not raise an error' do
        get '/test'
        expect(last_response.status).to eq 200
      end
    end
  end

  describe 'response header validation' do
    let(:app) do
      Rack::Builder.app do
        use OpenapiFirst::Middlewares::ResponseValidation, spec: './spec/data/response-header.yaml'
        run(lambda do |env|
          res = Rack::Response.new
          res.status = 201
          res.headers.merge!(MultiJson.load(Rack::Request.new(env).body))
          res.finish
        end)
      end
    end

    before do
      header Rack::CONTENT_TYPE, 'application/json'
    end

    it 'succeeds with a valid header' do
      post '/echo', json_dump({ 'Location' => '/echos/42', 'X-Id' => '42', 'OptionalWithoutSchema' => '432' })
      expect(last_response.status).to eq 201
      expect(last_response.headers['Location']).to eq '/echos/42'
      expect(last_response.headers['X-Id']).to eq '42'
    end

    it 'fails with an invalid header' do
      expect do
        post '/echo', json_dump({ 'Location' => '/echos/42', 'X-Id' => 'not-an-integer' })
      end.to raise_error OpenapiFirst::ResponseInvalidError
    end

    it 'ignores "Content-Type" header' do
      post '/echo', json_dump({ 'Location' => '/echos/42', 'Content-Type' => 'unknown' })
      expect(last_response.status).to eq 201
    end

    it 'fails with a missing header' do
      expect do
        post '/echo', json_dump({ 'X-Id' => '42' })
      end.to raise_error OpenapiFirst::ResponseInvalidError
    end
  end
end
