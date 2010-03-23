require 'set'
require 'inflector.rb'

# include Sonar::ClassDependencies onto a Module or Class
# then include that Module, or inherit from that Class,
# and declare dependencies amongst the descendants of
# that Module or Class, which can be queried on
# the Module or Class, and ordered by dependency
# e.g.
#
# module SomeDep ; include Sonar::ClassDependencies ; end
# class A ; include Base ; some_dep :b ; end
# class B ; include Base ; some_dep :c ; end
# class C ; include Base ; end
# SomeDep.ordered_dependencies
# => [:c, :b, :a]
# SomeDep.ordered_dependent_classes
# => [C, B, A]
#
# class AnotherDep ; include Sonar::ClassDependencies ; end
# class D < Top ; another_dep :e ; end
# class E < Top ; another_dep :f ; end
# class F < Top ; end
# AnotherDep.ordered_dependencies
# => [:f, :e, :d]
# AnotherDep.ordered_dependent_classes
# => [F, E, D]

module Sonar
  module ClassDependencies
    module ClassName
      def class_to_sym(klass)
        klass.to_s.underscore.to_sym
      end

      def sym_to_class(sym)
        eval(sym.to_s.camelize)
      end
    end

    class << self
      include Sonar::ClassDependencies::ClassName

      # generates an inclusion method [suitable for included() or inherited() ] on the module 
      # we are included into,
      # which generates value proxys for the class_dependencies and obj_descendants
      def generate_inclusion_method(mod, method_name)
        mc = mod.instance_eval{class << self ; self ; end}
        
        mc.send(:define_method, method_name) do |mod2|
          raise "include #{mod.to_s} on a Class... doesn't work with intermediate modules" if ! mod2.is_a? Class
          mod.descendants << class_to_sym(mod2)
          dep_method_name = class_to_sym(mod)
          $stderr << dep_method_name << "\n"
          mod2.instance_eval do
            mc2 = class << self ; self ; end
            mc2.send(:define_method, dep_method_name){|*params| mod.add_dependency(mod2, *params)}
          end
        end
      end
      
      def included(mod)
        mc = mod.instance_eval do
          class << self ; include BaseModuleMethods ; self ; end
        end
        # generate the dependency list value and the descendants value accessors
        # on first include : they return a closed over value
        dependencies = {}
        descendants = []
        mc.send(:define_method, :class_dependencies){dependencies}
        mc.send(:define_method, :descendants){descendants}

        # generate an included method if we are included into a module
        ClassDependencies::generate_inclusion_method(mod, :included)
        # and if we are included into a Class, then generate an inherited method too
        ClassDependencies::generate_inclusion_method(mod, :inherited) if mod.is_a? Class
      end
    end

    # methods for the base module, on which the dependency map and descendants list live
    module BaseModuleMethods
      include Sonar::ClassDependencies::ClassName

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
        find_dependencies_of(from_sym, Set.new()).delete(from).to_a
      end

      def ordered_dependencies
        descendants.sort do |a,b| 
          if all_dependencies_of(a).include?(b)
            +1
          elsif all_dependencies_of(b).include?(a)
            -1
          else
            0
          end
        end
      end

      def ordered_dependent_classes
        ordered_dependencies.map{|sym| sym_to_class(sym)}
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
end