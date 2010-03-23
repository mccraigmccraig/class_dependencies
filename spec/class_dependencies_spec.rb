require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "ClassDependencies" do
  
  class BaseDep
    include Sonar::ClassDependencies
  end

  class A < BaseDep
    base_dep :b
  end

  class B < BaseDep
    base_dep :c
  end

  class C < BaseDep
  end
  

  it "should correctly order class dependences" do
    BaseDep.ordered_dependencies.should == [:c, :b, :a]
  end

  it "should record dependency declarations" do
    BaseDep.class_dependencies.should == {:a=>[:b], :b=>[:c]}
  end
  
  it "should record class inheritance" do
    BaseDep.descendants == [:a, :b, :c]
  end

  module AnotherDep
    include Sonar::ClassDependencies
  end

  class D
    include AnotherDep
    another_dep :e
  end

  class E
    include AnotherDep
    another_dep :f
  end

  class F
    include AnotherDep
  end

  it "should correctly order class dependencies for module include" do
    AnotherDep.ordered_dependencies.should == [:f, :e, :d]
  end

  it "should record dependency declarations for module include" do
    AnotherDep.class_dependencies.should == {:d=>[:e], :e=>[:f]}
  end

end
