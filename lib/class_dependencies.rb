require 'set'
require 'tsort'
require 'inflector'

# include ClassDependencies onto a Module or Class
# then include that Module, or inherit from that Class,
# and declare dependencies amongst the descendants of
# that Module or Class, which can be queried on
# the Module or Class, and ordered by dependency
# e.g.
#
# module SomeDep ; include ClassDependencies ; end
# class A ; include Base ; some_dep :b ; end
# class B ; include Base ; some_dep :c ; end
# class C ; include Base ; end
# SomeDep.ordered_dependencies
# => [:c, :b, :a]
# SomeDep.ordered_dependent_classes
# => [C, B, A]
# SomeDep.descendants
# => [:a, :b, :c]
# SomeDep.descendant_classes
# => [A, B, C]
#
# class AnotherDep ; include ClassDependencies ; end
# class D < Top ; another_dep :e ; end
# class E < Top ; another_dep :f ; end
# class F < Top ; end
# AnotherDep.ordered_dependencies
# => [:f, :e, :d]
# AnotherDep.ordered_dependent_classes
# => [F, E, D]
#
# *NOTE* if your class already has an inherited() or included() method
# make sure to include ClassDependencies after that method is
# defined : Ruby has no after/before methods, so your method will
# overwrite the ClassDependencies versions, and dependency tracking
# will not work

module ClassDependencies
  class TSortHash < Hash
    include TSort
    def initialize(mod)
      @mod = mod
    end
    def tsort_each_node(&block)
      @mod.descendants.each(&block)
    end
    def tsort_each_child(node,&block)
      fetch(node,[]).each(&block)
    end
  end

  module ClassName
    def class_to_sym(klass)
      klass.to_s.underscore.to_sym
    end

    def sym_to_class(sym)
      eval(sym.to_s.camelize)
    end
  end

  class << self
    include ClassDependencies::ClassName

    # generates an inclusion method [suitable for included() or inherited() ] on the module 
    # we are included into,
    # which generates value proxys for the class_dependencies and obj_descendants
    def generate_inclusion_method(mod, method_name)
      mc = mod.instance_eval{class << self ; self ; end}
      
      # if there is already such a method, alias it
      if mod.respond_to?(method_name)
        aliased_method_name = "class_dependencies_#{method_name}"
        raise "can't include ClassDependencies twice" if mod.respond_to?(aliased_method_name)
        mc.send(:alias_method, aliased_method_name, method_name) 
      end

      mc.send(:define_method, method_name) do |mod2|
#        raise "include #{mod.to_s} on a Class... doesn't work with intermediate modules" if ! mod2.is_a? Class
        mod.descendants << class_to_sym(mod2)
        mod2.instance_eval do
          mc2 = class << self ; include ClassDependencies::ClassName ; self ; end
          dep_method_name = mod.relationship_name || class_to_sym(mod)
          mc2.send(:define_method, dep_method_name){|*params| mod.add_dependency(mod2, *params)}
        end

        # call any aliased method. if only Ruby had :after advice etc
        mod.send(aliased_method_name, mod2) if aliased_method_name
      end
    end
    
    def included(mod)
      mc = mod.instance_eval do
        class << self ; include BaseModuleMethods ; self ; end
      end
      # generate the dependency list value and the descendants value accessors
      # on first include : they return a closed over value
      dependencies = TSortHash.new(mod)
      descendants = []
      mc.send(:define_method, :class_dependencies){dependencies} if ! mc.instance_methods.include?("class_dependencies")
      mc.send(:define_method, :descendants){descendants} if ! mc.instance_methods.include?("descendants")

      # generate an included method if we are included into a module
      ClassDependencies::generate_inclusion_method(mod, :included)
      # and if we are included into a Class, then generate an inherited method too
      ClassDependencies::generate_inclusion_method(mod, :inherited) if mod.is_a? Class
    end
  end

  # methods for the base module, on which the dependency map and descendants list live
  module BaseModuleMethods
    include ClassDependencies::ClassName

    attr_reader :relationship_name

    def set_relationship_name(name)
      @relationship_name = name
    end

    def add_dependency(from, to)
      from_sym = class_to_sym(from)
      to_sym = class_to_sym(to)
      return if from_sym == to_sym
      deps = (class_dependencies[from_sym] ||= [])
      raise "circular dependency" if all_dependencies_of(to_sym).include?(from_sym)
      deps << to_sym
      nil
    end

    def all_dependencies_of(from)
      from_sym = class_to_sym(from)
      find_dependencies_of(from_sym, Set.new()).delete(from_sym).to_a
    end

    def all_dependencies_of_classes(from)
      all_dependencies_of(from).map{|sym| sym_to_class(sym)}
    end

    def ordered_dependencies
      class_dependencies.tsort
    end

    def ordered_dependent_classes
      ordered_dependencies.map{|sym| sym_to_class(sym)}
    end

    def descendant_classes
      descendants.map{|sym| sym_to_class(sym)}
    end

    private

    def find_dependencies_of(from, deps)
      deps << from
      (class_dependencies[from]||[]).each do |dep|
        find_dependencies_of(dep, deps) if !deps.include?(dep)
      end
      deps
    end
  end
end

