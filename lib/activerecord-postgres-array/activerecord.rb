module ActiveRecord
  class ArrayTypeMismatch < ActiveRecord::ActiveRecordError
  end

  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      POSTGRES_ARRAY_TYPES = %w( string text integer float decimal datetime timestamp time date binary boolean uuid )

      def native_database_types_with_array(*args)
        native_database_types_without_array.merge(POSTGRES_ARRAY_TYPES.inject(Hash.new) {|h, t| h.update("#{t}_array".to_sym => {:name => "#{t}_array"})})
      end
      alias_method_chain :native_database_types, :array

    
      # Quotes a value for use in an SQL statement
      def quote_with_array(value, column = nil)
        if value && column && column.sql_type =~ /\[\]$/
          raise ArrayTypeMismatch, "#{column.name} must have a Hash or a valid array value (#{value})" unless value.kind_of?(Array) || value.valid_postgres_array?          
          return value.to_postgres_array
        end
        quote_without_array(value,column)
      end
      alias_method_chain :quote, :array
    end

    class TableDefinition
      # Adds array type for migrations. So you can add columns to a table like:
      #   create_table :people do |t|
      #     ...
      #     t.string_array :real_energy
      #     t.decimal_array :real_energy, :precision => 18, :scale => 6
      #     ...
      #   end
      PostgreSQLAdapter::POSTGRES_ARRAY_TYPES.each do |column_type|
        define_method("#{column_type}_array") do |*args|
          options = args.extract_options!
          base_type = @base.type_to_sql(column_type.to_sym, options[:limit], options[:precision], options[:scale])
          column_names = args
          column_names.each { |name| column(name, "#{base_type}[]", options) }
        end
      end
    end

    class PostgreSQLColumn < Column
      # Does the type casting from array columns using String#from_postgres_array or Array#from_postgres_array.
      def type_cast_code_with_array(var_name)
        if type.to_s =~ /_array$/
          base_type = type.to_s.gsub(/_array/, '')
          "#{var_name}.from_postgres_array(:#{base_type})"
        else
          type_cast_code_without_array(var_name)
        end
      end
      alias_method_chain :type_cast_code, :array


      # Adds the array type for the column.
      def simplified_type_with_array(field_type)
        if field_type =~ /^numeric.+\[\]$/
          :decimal_array
        elsif field_type =~ /\[\]$/
          field_type.gsub(/\[\]/, '_array')
        else
          simplified_type_without_array(field_type)
        end
      end
      alias_method_chain :simplified_type, :array
    end
  end
end
