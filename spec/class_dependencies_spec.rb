require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

# camelize and underscore take from ActiveSupport
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
  def camelize
    Inflector::camelize(self)
  end
  def underscore
    Inflector::underscore(self)
  end
end

describe "ClassDependencies" do
  
  class Top
    include Sonar::ClassDependencies
  end

  class A < Top
    depends_on :b
  end

  class B < Top
    depends_on :c
  end

  class C < Top
  end
  

  it "should correctly order class dependences" do
    Top.ordered_dependencies.should == [:c, :b, :a]
  end

  it "should record dependency declarations" do
    Top.class_dependencies.should == {:a=>[:b], :b=>[:c]}
  end
  
  it "should record class inheritance" do
    Top.descendants == [:a, :b, :c]
  end

end
