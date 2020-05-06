module Bamboozled
  module API
    class Employee < Base

      def initialize(subdomain, api_key, httparty_options = {}, tabular_data_tables = [])
        super(subdomain, api_key, httparty_options)
        tabular_data_tables += [:job_info, :employment_status, :compensation, :dependents, :contacts]
        @tabular_data_tables = tabular_data_tables.uniq
      end

      def method_missing(method, *args)
        # Tabular data
        if @tabular_data_tables.include?(method) && args.length == 1
          request(:get, "employees/#{args[0]}/tables/#{method.to_s.gsub(/_(.)/) {|e| $1.upcase}}")
        else
          super
        end
      end

      def respond_to_missing?(method, *)
        @tabular_data_tables.include?(method.to_s) || super
      end

      def all(fields = nil)
        response = request(:get, "employees/directory")

        if fields.nil? || fields == :default
          Array(response['employees'])
        else
          employees = []
          response['employees'].map{|e| e['id']}.each do |id|
            employees << find(id, fields)
          end
          employees
        end
      end

      def find(employee_id, fields = nil)
        fields = FieldCollection.wrap(fields).to_csv

        request(:get, "employees/#{employee_id}?fields=#{fields}")
      end

      def last_changed(date = "2011-06-05T00:00:00+00:00", type = nil)
        query = Hash.new
        query[:since] = date.respond_to?(:iso8601) ? date.iso8601 : date
        query[:type] = type unless type.nil?

        response = request(:get, "employees/changed", query: query)
        response["employees"]
      end

      def time_off_estimate(employee_id, end_date)
        end_date = end_date.strftime("%F") unless end_date.is_a?(String)
        request(:get, "employees/#{employee_id}/time_off/calculator?end=#{end_date}")
      end

      def photo_binary(employee_id)
        request(:get, "employees/#{employee_id}/photo/small")
      end

      def photo_url(employee)
        if (Float(employee) rescue false)
          e = find(employee, ['workEmail', 'homeEmail'])
          employee = e['workEmail'].nil? ? e['homeEmail'] : e['workEmail']
        end

        digest = Digest::MD5.new
        digest.update(employee.strip.downcase)
        "http://#{@subdomain}.bamboohr.com/employees/photos/?h=#{digest}"
      end

      def add(employee_details)
        details = generate_xml(employee_details)
        options = {body: details}

        request(:post, "employees/", options)
      end

      def update(bamboo_id, employee_details)
        details = generate_xml(employee_details)
        options = { body: details }

        request(:post, "employees/#{bamboo_id}", options)
      end

      private

      def generate_xml(employee_details)
        "".tap do |xml|
          xml << "<employee>"
          employee_details.each { |k, v| xml << "<field id='#{k}'>#{v}</field>" }
          xml << "</employee>"
        end
      end
    end
  end
end
