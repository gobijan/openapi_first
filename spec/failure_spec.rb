# frozen_string_literal: true

RSpec.describe OpenapiFirst::Failure do
  describe '.fail!' do
    it 'throws a failure' do
      expect do
        described_class.fail!(:invalid_body)
      end.to throw_symbol(described_class::FAILURE, instance_of(described_class))
    end

    context 'with an unknown argument' do
      it 'throws a failure' do
        expect do
          described_class.fail!(:unknown)
        end.to raise_error(ArgumentError)
      end
    end
  end

  describe '#type' do
    it 'returns the error type' do
      expect(described_class.new(:invalid_body).type).to eq(:invalid_body)
    end
  end

  describe '#type' do
    it 'returns the error type' do
      expect(described_class.new(:invalid_body).type).to eq(:invalid_body)
    end
  end

  describe '#raise!' do
    it 'raises an error' do
      expect do
        described_class.new(:invalid_body).raise!
      end.to raise_error(OpenapiFirst::RequestInvalidError)
    end

    context 'with a lot of errors' do
      let(:failure) do
        errors = 100.times.map do |i|
          instance_double(OpenapiFirst::Schema::ValidationError, error: "something is wrong over there #{i}")
        end
        described_class.new(:invalid_body, errors:)
      end

      it 'raises an error with a reduced message' do
        expect do
          failure.raise!
        end.to raise_error(OpenapiFirst::RequestInvalidError,
                           'Request body invalid: something is wrong over there 0. something is wrong over there 1. ' \
                           'something is wrong over there 2. something is wrong over there 3. ... (100 errors total)')
      end
    end
  end
end
