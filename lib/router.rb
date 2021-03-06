class Router

  def initialize(routingtable, clients=nil)
    $Log.info("Initializing router")
    @routingtable = routingtable
    @clients = clients
  end

  def route(clientaddr, data, socket=nil)
    $Log.info("Got Data: #{data}")
    source_id = data['source_id']
    signal = delete_carriage_return(data['signal'])
    payload = data['payload']
    arguments = data['arguments']
    client_id = parse_id(source_id, clientaddr)
    group_specific_signal = get_matching_group_specific_signal(client_id, signal, payload)
    device_specific_signal = signal + "@" + client_id.to_s
    if test_payload_type(payload)
      device_specific_signal_with_payload = signal + "@" + client_id.to_s + "=" + payload.to_s
    else
      device_specific_signal_with_payload = nil
    end
    $Log.info("
    #############
    New Data:
    Signal: #{signal}
    Device_Signal: #{device_specific_signal}
    Group_Signals: #{group_specific_signal}")
    $Log.info("
    Device_Signal with Payload: #{device_specific_signal_with_payload}") if device_specific_signal_with_payload
    $Log.info("
    Payload: #{payload}
    Arguments: #{arguments}
    from Client: #{client_id}
    #############\n")
    if signal == 'register' and @routingtable.has_key?(signal)
      @clients.register(client_id, payload, socket)
      return
    else
      if @routingtable.has_key?(device_specific_signal_with_payload)
        selected_signal = device_specific_signal_with_payload
      elsif @routingtable.has_key?(device_specific_signal)
        selected_signal = device_specific_signal
      elsif group_specific_signal
        selected_signal = group_specific_signal
      elsif @routingtable.has_key?(signal)
        selected_signal = signal
      else
        $Log.error("   No such Signal: #{signal}")
      end
    end
    begin
      if arguments.empty?
        begin
          @routingtable[selected_signal].call(client_id, payload)
        rescue ArgumentError => e
          $Log.error("Method #{@routingtable[signal]} requires arguments: #{e}")
        end
      else
        begin
          @routingtable[selected_signal].call(client_id, payload, arguments)
        rescue ArgumentError => e
          $Log.error("Method #{@routingtable[signal]} does not support arguments: #{e}")
          @routingtable[selected_signal].call(client_id, payload)
        end
      end
    rescue NoMethodError => e
      $Log.error("Couldn't call signal: '#{selected_signal}' Class: '#{selected_signal.class}'. Error: #{e}")
    end
  end

  def get_matching_group_specific_signal(client_id, signal, payload)
    matching_group_specific_signals = []
    if @clients
      if @clients.has_key?(client_id)
        @clients[client_id].clientgroups.each do |clientgroupname|
          if payload
            if test_payload_type(payload)
              group_signal_with_payload = signal + "@" + clientgroupname + "=" + payload.to_s
              if @routingtable.has_key?(group_signal_with_payload)
                return group_signal_with_payload
              end
            end
          end
          group_signal = signal + "@" + clientgroupname
          if @routingtable.has_key?(group_signal)
            return group_signal
          end
        end
      end
    end
    return nil
  end

  def test_payload_type(payload)
    return true if payload.kind_of?(String)
    return true if payload.kind_of?(TrueClass)
    return true if payload.kind_of?(FalseClass)
    return false
  end

  def parse_id(source_id, clientaddr)
    return @clients.by_ip(clientaddr).id if @clients.by_ip(clientaddr) if @clients
    return "0"
  end

  def delete_carriage_return(data)
    return data.delete("\n")
  end

end

class Actionlist

  def initialize(name)
    @name = name
    @actions = []
  end

  def add_action(action, pos=-1)
    @actions.insert(pos, action)
  end

  def call(id, data, arguments=nil)
    @actions.each do |action|
      $Log.info("Calling #{action} from Actionlist #{@name}")
      action.call(id, data)
    end
  end

end

class RemoteAction

  def initialize(client, remote_signal, arguments={})
    $Log.info("Adding RemoteAction: #{remote_signal} on #{client.id} with arguments #{arguments}")
    @client = client
    @remote_signal = remote_signal
    @arguments = arguments
    client.add_remote_signal(remote_signal)
  end

  def call(id, payload, arguments=nil)
    $Log.info("Called RemoteAction. Sending #{@remote_signal}||#{payload}||#{@arguments} to #{@client.id} SourceID: #{id}")
    if @client.online?
      @client.send(@remote_signal, payload, @arguments, source_id=id)
    else
      $Log.error("  Destination Client #{client.ip}:#{client.port} is offline")
    end
  end

  attr_reader :client

end

class RoutingTable < Hash

  def initialize(site_config={}, clients={})
    @site_config = site_config
    @clients = clients
  end

  def add_signals(signalhash)
    signalhash.each_pair do |signal, action|
      self.add_signal(signal, action)
    end
  end

  def add_signal(signal, action)
    signal = signal.to_s if signal.is_a?(Symbol)
    if self.has_key?(signal)
      $Log.error("Signal exists")
    else
      $Log.info("Added Signal '#{signal}' routed to '#{action}'")
      self[signal] = action
    end
  end

  def remove_signal(signal)
    if self.has_key?(signal)
      self.delete(signal)
    else
      $Log.error("No such Signal")
    end
  end

  def add_config_actionlists
    return unless @site_config['actions']
    @site_config['actions'].each do |name, content|
      $Log.info("Adding ActionList: #{name}\n  -> Actions: #{content.keys}")
      actionlist =  Actionlist.new(name)
      #actions = [actions] if actions.kind_of??(String)
      content.each_pair do |action, arguments|
        remote_action = create_remote_action(action, arguments)
        actionlist.add_action(remote_action) if remote_action
      end
      add_signal(name, actionlist)
    end
  end

  def add_config_inputs
    $Log.info("Adding inputs")
    return unless @site_config['inputs']
    @site_config['inputs'].each do |name, action|
      $Log.info("  Routing input: #{name} to action: #{action}")
      if self.has_key?(action)
        add_signal(name, self[action])
      else
        remote_action = create_remote_action(action, {})
        add_signal(name, remote_action) if remote_action
      end
    end
  end

  def create_remote_action(action, arguments)
    actionname, dest_client_id = action.split('@')
    pluginname, pluginmethodname = actionname.split('.')
    $Log.info("  Adding remote Action: Pluginname: #{pluginname}, Plugin Method Name: #{pluginmethodname}, Client_ID: #{dest_client_id}, Arguments: #{arguments}")
    unless dest_client_id
      $Log.error("  Local Actions are not supported: Pluginname: #{pluginname}, Plugin Method Name: #{pluginmethodname}")
      return nil
    end
    if @clients.has_key?(dest_client_id)
      client = @clients[dest_client_id]
      remote_action = RemoteAction.new(client, actionname, arguments)
      return remote_action
    else
      $Log.error("Error on Config. No such client: #{dest_client_id}")
    end
  end

end
