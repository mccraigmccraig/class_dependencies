require 'set'

# when included, defines a class method on the module
# which can be used to declare dependencies amongst descendants
# of that module
# e.g.
# class Top ; include Sonar::ClassDependencies ; end
# class A < Top ; depends_on :b ; end
# class B < Top ; depends_on :c ; end
# class C < Top ; end
#
# Top.ordered_dependencies
# => [:c, :b, :a]
# Top.ordered_dependent_classes
# => [C, B, A]
#
module Sonar
  module ClassDependencies
    class << self

      # generates a method from a closure returning the value
      def generate_closure_value_method(obj, method_name, value)
        obj.send(:define_method, method_name) do
          value
        end
      end

      def included(mod)
        mod.instance_eval do
          class << self
            ClassDependencies::generate_closure_value_method(self, :class_dependencies, {})
            ClassDependencies::generate_closure_value_method(self, :descendants, [])
            include( ClassMethods )
          end 
        end
      end
    end
    
    module ClassMethods
      def inherited(subclass)
        descendants << subclass.to_s.underscore.to_sym
      end

      def class_to_sym(klass)
        klass.to_s.underscore.to_sym
      end

      def sym_to_class(sym)
        eval(sym.to_s.camelize)
      end

      def depends_on(dep)
        add_dependency(self, dep)
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

      def add_dependency(from, to)
        from_sym = class_to_sym(from)
        to_sym = class_to_sym(to)
        return if from_sym == to_sym
        deps = (class_dependencies[from_sym] ||= [])
        raise "circular dependency" if all_dependencies_of(to_sym).include?(from_sym)
        deps << to_sym
        nil
      end

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
