require 'active_support/concern'

module Enumerize
  module Base
    extend ActiveSupport::Concern

    included do
      if respond_to?(:validate)
        validate :_validate_enumerized_attributes
      end
    end

    module ClassMethods
      def enumerize(name, options={})
        raise ArgumentError, "Enumerized attribute #{name} is already defined" if enumerized_attributes[name]

        attr = Attribute.new(self, name, options)
        enumerized_attributes << attr

        unless methods.include?(attr.name)
          _enumerize_module._class_methods.module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{attr.name}
              enumerized_attributes[:#{attr.name}]
            end
          RUBY
        end

        attr.define_methods!(_enumerize_module)
      end

      def enumerized_attributes
        @enumerized_attributes ||= AttributeMap.new
      end

      def inherited(subclass)
        enumerized_attributes.add_dependant subclass.enumerized_attributes
        super
      end

      private

      def _enumerize_module
        @_enumerize_module ||= begin
          mod = Module.new
          include mod
          mod
        end
      end
    end

    def initialize(*)
      super
      self.class.enumerized_attributes.each do |attr|
        if !public_send(attr.name) && !_enumerized_values_for_validation.key?(attr.name)
          public_send("#{attr.name}=", attr.default_value)
        end
      end
    end

    def read_attribute_for_validation(key)
      if _enumerized_values_for_validation.has_key?(key)
        _enumerized_values_for_validation[key]
      else
        super
      end
    end

    private

    def _enumerized_values_for_validation
      @_enumerized_values_for_validation ||= {}
    end

    def _validate_enumerized_attributes
      self.class.enumerized_attributes.each do |attr|
        value = read_attribute_for_validation(attr.name)
        next if value.blank?

        if attr.kind_of? Multiple
          errors.add attr.name unless value.respond_to?(:all?) && value.all? { |v| v.blank? || attr.find_value(v) }
        else
          errors.add attr.name, :inclusion unless attr.find_value(value)
        end
      end
    end
  end
end
