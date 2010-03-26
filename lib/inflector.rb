# camelize and underscore taken from ActiveSupport

if !defined? Inflector
  module Inflector
    extend self

    def camelize(lower_case_and_underscored_word, first_letter_in_uppercase = true)
      if first_letter_in_uppercase
        lower_case_and_underscored_word.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
      else
        lower_case_and_underscored_word.first.downcase + camelize(lower_case_and_underscored_word)[1..-1]
      end
    end

    def underscore(camel_cased_word)
      camel_cased_word.to_s.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
    end
  end

  class String
    def camelize(first_letter = :upper)
      case first_letter
      when :upper then Inflector.camelize(self, true)
      when :lower then Inflector.camelize(self, false)
      end
    end
    alias_method :camelcase, :camelize

    def underscore
      Inflector::underscore(self)
    end
  end
end
