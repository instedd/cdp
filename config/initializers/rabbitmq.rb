class Rabbitmq
  attr_reader :connection, :channel, :queue, :exchange

  def initialize
    @connection = Bunny.new
    @connection.start

    @channel = @connection.create_channel
    @queue  = @channel.queue("bunny.examples.hello_world", :auto_delete => true)
    @exchange  = @channel.default_exchange

    @queue.subscribe do |delivery_info, metadata, payload|
      SubscriptionDispatcher.new(delivery_info, metadata, payload).run
    end
  end

  def enqueue(content = {})
    @exchange.publish(content.to_json, :routing_key => @queue.name)
  end

  class << self
    attr_reader :active_connection
  end

  @active_connection = self.new
end

# if defined?(PhusionPassenger) # otherwise it breaks rake commands if you put this in an initializer
#   PhusionPassenger.on_event(:starting_worker_process) do |forked|
#     if forked
#        # We’re in a smart spawning mode
#        # Now is a good time to connect to RabbitMQ
#        $rabbitmq_connection = Bunny.new; $rabbitmq_connection.start
#        $rabbitmq_channel    = @connection.create_channel
#     end
#   end
# end
