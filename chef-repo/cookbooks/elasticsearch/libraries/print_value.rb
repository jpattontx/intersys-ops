module Extensions
  module Templates

    # An extension method for convenient printing of values in ERB templates.
    #
    # The method provides several ways how to evaluate the value:
    #
    # 1. Using the key as a node attribute:
    #
    #    <%= print_value 'bar' -%> is evaluated as: `node[:bar]`
    #
    #    You may use a dot-separated key for nested attributes:
    #
    #    <%= print_value 'foo.bar' -%> is evaluated in multiple ways in this order:
    #
    #    a) as `node['foo.bar']`,
    #    b) as `node['foo_bar']`,
    #    c) as `node.foo.bar` (ie. `node[:foo][:bar]`)
    #
    # 2. You may also provide an explicit value for the method, which is then used:
    #
    #    <%= print_value 'bar', node[:foo] -%>
    #
    # You may pass a specific separator to the method:
    #
    #    <%= print_value 'bar', separator: '=' -%>
    #
    # Do not forget to use an ending dash (`-`) in the ERB block, so lines for missing values are not printed!
    #
    def print_value nodetype, key, value=nil, options={}
      separator = options[:separator] || ': '
      existing_value   = value

      # NOTE: A value of `false` is valid, we need to check for `nil` explicitely

      begin
        existing_value = node.elasticsearch[nodetype][key] if existing_value.nil? and not node.elasticsearch[nodetype].nil? and not node.elasticsearch[nodetype][key].nil?
        existing_value = node.elasticsearch[nodetype][key.tr('.', '_')] if existing_value.nil? and not node.elasticsearch[nodetype][key.tr('.', '_')].nil?
        existing_value = key.to_s.split('.').inject(node.elasticsearch[nodetype]) { |result, attr| result[attr] } rescue nil if existing_value.nil? and not node.elasticsearch[nodetype].nil?
      rescue
        existing_value = value
      end

      begin
        existing_value = node.elasticsearch[key] if existing_value.nil? and not node.elasticsearch[key].nil?
        existing_value = node.elasticsearch[key.tr('.', '_')] if existing_value.nil? and not node.elasticsearch[key.tr('.', '_')].nil?
        existing_value = key.to_s.split('.').inject(node.elasticsearch) { |result, attr| result[attr] } rescue nil if existing_value.nil?
      rescue
        existing_value = value
      end

      [key, separator, existing_value.to_s, "\n"].join unless existing_value.nil?
    end

  end
end
