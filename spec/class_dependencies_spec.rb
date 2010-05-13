require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "ClassDependencies" do
  
  class BaseDep
    include ClassDependencies
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

  it "should return descendants as classes" do
    BaseDep.descendant_classes == [A, B, C]
  end

  it "should not return the root in all_dependencies_of" do
    BaseDep.all_dependencies_of(A).to_set.should == [:b,:c].to_set
    BaseDep.all_dependencies_of(:a).to_set.should == [:b,:c].to_set
    BaseDep.all_dependencies_of(B).should == [:c]
    BaseDep.all_dependencies_of(:b).should == [:c]
  end

  it "should return classes in all_dependencies_of_classes" do
    BaseDep.all_dependencies_of_classes(A).to_set.should == [B,C].to_set
  end

  module AnotherDep
    include ClassDependencies

    set_relationship_name  :depends_on
  end

  class D
    include AnotherDep
    depends_on :e
  end

  class E
    include AnotherDep
    depends_on :f
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

  module WithIncludedMethod
    class << self
      attr_accessor :count
      def included(mod)
        self.count ||= 0
        self.count += 1
      end 
    end

    include ClassDependencies
    set_relationship_name :depends_on
  end

  class G
    include WithIncludedMethod
    depends_on :h
  end

  class H
    include WithIncludedMethod
  end
    

  it "should call any existing included method" do
    WithIncludedMethod.ordered_dependencies.should == [:h, :g]
    WithIncludedMethod.count.should == 2
  end

  class WithInheritedMethod
    class << self
      attr_accessor :count
      def inherited(mod)
        self.count ||= 0
        self.count += 1
      end 
    end

    include ClassDependencies
    set_relationship_name :depends_on
  end

  class I < WithInheritedMethod
    depends_on :j
  end

  class J < WithInheritedMethod
  end

  it "should call any existing inherited method" do
    WithInheritedMethod.ordered_dependencies.should == [:j, :i]
    WithInheritedMethod.count.should == 2
  end

  module Foo
    include ClassDependencies
  end

  class K
    include Foo
  end

  class L
    include Foo
  end

  it "should return all dependencies even without relationships" do
    Foo.ordered_dependencies.to_set.should == Set.new([:k,:l])
  end

  module Woo
    include ClassDependencies
  end

  module M
    include Woo
  end

  module N
    include Woo
  end

  it "should work with modules too" do
    Woo.descendants.to_set.should == Set.new([:n, :m])
  end
end
