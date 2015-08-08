require 'socket'
require 'aws-sdk'

class EC2
  class Host
    ARRAY_TAG_DELIMITER = ','
    ROLE_TAG_DELIMITER = ':'

    include Enumerable

    def self.instances
      # I do not use describe_instances(filter:) because it does not support array tag ..
      @instances ||= begin
        ec2 = Aws::EC2::Client.new
        ec2.describe_instances.reservations.map(&:instances).flatten
      end
    end

    # @return [Host::Data] representing myself
    def self.me
      name = Socket.gethostname
      new(hostname: name).each do |i|
        return i
      end
      raise "whoami? #{name} not found"
    end

    # @param [Array of Hash, or Hash] conditions
    def initialize(*conditions)
      conditions = [{}]   if conditions.empty?
      conditions = [conditions] if conditions.kind_of?(Hash)
      raise conditionumentError, "Array of Hash expected" unless conditions.all? {|h| h.kind_of?(Hash)}
      @conditions = []
      conditions.each do |condition|
        @conditions << Hash[condition.map {|k, v| [k, Array(v).map(&:to_s)]}]
      end
    end

    # @yieldparam [Host::Data] data entry
    def each(&block)
      @conditions.each do |condition|
        search(self.class.instances, condition, &block)
      end
      return self
    end

    private

    def search(instances, condition)
      instances.each do |i|
        d = EC2::Host::HostData.initialize(i)
        next unless d.match?(condition)
        yield d
      end
    end
  end
end
