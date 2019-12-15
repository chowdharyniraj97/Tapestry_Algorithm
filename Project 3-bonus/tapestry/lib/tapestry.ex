defmodule Tapestry do
  use GenServer
  require Logger

  def fire(numNodes,numRequest,numKill) do
    Registry.start_link(name: :my_registry, keys: :unique)
    :ets.new(:mapping, [:set, :public, :named_table])
    :ets.new(:result, [:set, :public, :named_table])
    plist=[]
    klist=[]
    #if(numNodes<=20) do
      Enum.map(1..numNodes, fn(x)-> start_node(x) end)
      Enum.map(1..numNodes, fn(y)-> set_neigh(y,numNodes) end)
      #printftable(numNodes)
    #else
      #Enum.map(1..numNodes-20, fn(x)-> start_node(x) end)
      #Enum.map(1..numNodes-20, fn(y)-> set_neigh(y,numNodes-20) end)
      #IO.puts "Created #{numNodes-20} nodes"
      #IO.puts "Routing tables-"
      #printftable(numNodes-20)
      #IO.puts("Creating remaining 20 nodes")
      #Enum.map(numNodes-19..numNodes, fn(x)-> start_node(x) end)
      #Enum.map(1..numNodes, fn(y)-> set_neigh(y,numNodes) end)
      #IO.puts "Created remaining 20 nodes"
      #IO.puts "Routing tables of entire network-"
      #printftable(numNodes)
    #end
    plist = Enum.map(1..numNodes, fn(x) -> List.insert_at(plist, x-1, x) end)
    plist = List.flatten(plist)
    #IO.inspect(plist)
    plist = Enum.reduce(1..numKill,plist, fn(_z), plist ->
      random_number = Enum.random(plist)
      _klist = klist ++ [random_number]
      plist = List.delete(plist,random_number)
      #IO.puts "Inside- "
      #IO.inspect plist
      plist
    end)
    klist = Enum.map(1..numNodes, fn(x)->
      if(!Enum.member?(plist,x)) do
        _klist = klist ++ [x]
      else
        klist
      end
    end)
    klist = List.flatten(klist)
    plist = List.flatten(plist)
    Enum.map(klist,fn(x) ->
      #random_number=Enum.at(klist,x-1)
      GenServer.stop(via_tuple(x))
      killed(x,numNodes,klist)
    end)
    #IO.puts("Ouside klist-")
    #IO.inspect(klist)
    #IO.puts("Outside plist-")
    #IO.inspect plist
    #printftable(numNodes,plist)
    _hops=[-1]
    hops = Enum.map(1..numNodes,fn(a) ->
      p = Enum.map(1..numRequest, fn(_b)->
        random_number = Enum.random(plist)
            if(random_number != a && Enum.member?(plist,a)) do
              route(a,random_number,0)
            end
        #IO.puts "Maximum hops for #{a} to #{random_number} = #{hops}"
      end)
      #IO.inspect p
      find_max(p,0)
    end)
    #IO.inspect hops
    max_hops=find_max(hops,0)
    IO.puts "Maximum hops is #{max_hops} for #{numNodes} nodes with #{numRequest} request(s) after #{numKill} node(s) die permanently "
  end

  def start_node(x) do
    hash_val=(String.slice(Base.encode16(:crypto.hash(:sha256,Integer.to_string(x))),0,8))
    :ets.insert(:mapping, {x, hash_val})
    :ets.insert(:mapping, {hash_val, x})
    neigh_table=Enum.reduce(0..7, %{}, fn x, acc ->
      Enum.reduce(0..15, acc, fn y, acc ->
        Map.put(acc, {x, y}, [])
      end)
    end)
    GenServer.start_link(__MODULE__,[hash_val,neigh_table,x], name: via_tuple(x))
  end

  def set_neigh(x,numNodes) do
    curr=GenServer.call(via_tuple(x),:print)
    curr=Enum.at(curr,0)
    perm=curr
    for i <- 1..numNodes do
      if (i != x) do
        b=GenServer.call(via_tuple(i),:print)
        b=Enum.at(b,0)
        count=check(curr,b,0)
        GenServer.cast(via_tuple(x),{:gen_neigh,b,count})
      end
      if(i == x) do
        check_same(curr,0,x,perm)
      end
    end
  end

  def check(curr,b,count) do
    x=String.at(curr,0)
    y=String.at(b,0)
    if(x == y && count<8) do
      check(String.slice(curr,1..(7-count)),String.slice(b,1..(7-count)),count+1)
    else
      count
    end
  end

  def check_same(curr,count,x,perm) do
    if(count<8) do
      GenServer.cast(via_tuple(x),{:gen_neigh,perm,count})
      check_same(String.slice(curr,1..String.length(curr)),count+1,x,perm)
    end
  end

  def route(c,d,hops) do
    [{_,hash_origin}]= :ets.lookup(:mapping,c)
    [{_,hash_dest}]= :ets.lookup(:mapping,d)
    #IO.inspect "#{hash_origin} #{hash_dest}"
    count=check(hash_origin,hash_dest,0)
    pos = String.at(hash_dest,count)
    pos = String.to_integer(pos,16)
    #IO.inspect("c= #{c}, d= #{d}" )
    origin=GenServer.call(via_tuple(c), :print)
    s_table=Enum.at(origin,1)

    a = Map.get(s_table,{count,pos})
    #IO.inspect "#{a}"
    if (Enum.at(a,0) == hash_dest) do
      hops
    else
      if(Enum.at(a,0) == nil) do
        0
      else
        [{_,ans}]=:ets.lookup(:mapping,Enum.at(a,0))
        route(ans,d,hops+1)
      end
    end
  end

  def printftable(numNodes,plist) do
    Enum.map(1..numNodes, fn(z)->
      if(Enum.member?(plist, z)) do
      k = GenServer.call(via_tuple(z),:print)
      k = Enum.at(k,1)
      Enum.reduce(0..7, %{}, fn x, acc ->
        Enum.reduce(0..15, acc, fn y, _acc ->
          l=Map.get(k, {x, y})
          if(l != []) do
            IO.puts "For id = #{z}: row = #{x}, column = #{y} and value = #{l}"
          end
        end)
      end)
      end
    end)
  end

  def killed(n,numNodes,klist) do
    [{_,hash_value}]= :ets.lookup(:mapping,n)
    #IO.puts "Killed node = #{hash_value}"
    Enum.map(1..numNodes, fn(x)->
      if(!Enum.member?(klist,x)) do
        [{_,hash_dest}]= :ets.lookup(:mapping,x)
        #IO.puts "Current node = #{hash_dest}"
        count=check(hash_dest,hash_value,0)
        GenServer.cast(via_tuple(x),{:update,count,hash_value})
      end
    end)
  end

  def handle_cast({:update,count,b},state) do
    [s_val,s_table,x]=state
    pos = String.at(b,count)
    pos = String.to_integer(pos,16)
    #pos = Integer.to_string(pos,16)
    a = Map.get(s_table,{count,pos})
    s_table = cond do
      Enum.at(a,0)==b ->
        #IO.puts "For x= #{x}"
        #IO.puts Enum.at(a,0)
        #IO.puts hash_value
        a = a -- [Enum.at(a,0)]
        #List.delete_at(a, 0)
        Map.put(s_table,{count,pos},a)
      Enum.at(a,1)==b ->
        a = a -- [Enum.at(a,1)]
        #List.delete_at(a, 1)
        Map.put(s_table,{count,pos},a)
      Enum.at(a,2)==b ->
        a = a -- [Enum.at(a,2)]
        #List.delete_at(a, 2)
        Map.put(s_table,{count,pos},a)
      true ->
        s_table
    end
    #IO.inspect "a = #{a}"

    {:noreply,[s_val,s_table,x]}
  end

  def handle_cast({:gen_neigh,b,count},state) do
    [s_val,s_table,x]=state
    pos = String.at(b,count)
    pos = String.to_integer(pos,16)
    #pos = Integer.to_string(pos,16)
    a = Map.get(s_table,{count,pos})
    s_table=cond do
    a == [] ->
        Map.put(s_table,{count,pos},[b])
    Enum.count(a)==1 ->
        a=cond do
          whoisbigger(Enum.at(a,0),b,s_val) ->
            List.insert_at(a, 0, b)
          true -> List.insert_at(a, 1, b)
        end
        Map.put(s_table,{count,pos},a)
    Enum.count(a)==2 ->
      a=cond do
        whoisbigger(Enum.at(a,0),b,s_val) ->
          List.insert_at(a, 0, b)
        whoisbigger(Enum.at(a,1),b,s_val) ->
          List.insert_at(a, 1, b)
        true ->
          List.insert_at(a, 2, b)
      end
      Map.put(s_table,{count,pos},a)
    Enum.count(a)==3 ->
        a=cond do
          whoisbigger(Enum.at(a,2),b,s_val) ->
            a = List.delete_at(a, 2)
            cond do
              whoisbigger(Enum.at(a,1),b,s_val) ->
                cond do
                  whoisbigger(Enum.at(a,0),b,s_val) ->
                    List.insert_at(a, 0, b)
                  true ->
                    List.insert_at(a, 1, b)
                end
              true ->
                  List.insert_at(a, 2, b)
            end
          true -> a
        end
        Map.put(s_table,{count,pos},a)
    true ->
        s_table
    end
    {:noreply,[s_val,s_table,x]}
  end

  def whoisbigger(a,b,s_val) do
    if abs(elem(Integer.parse(a,16),0) - elem(Integer.parse(s_val,16),0)) > abs(elem(Integer.parse(b,16),0) - elem(Integer.parse(s_val,16),0)) do
      true
    else
      false
    end
  end

  def find_max([],max) do
    max
  end

  def find_max(list,max) do
    [head | tail] = list
    cond do
      head == nil -> find_max(tail,max)
      head > max -> find_max(tail,head)
      true -> find_max(tail,max)
    end
  end

  def handle_call(:print,_,state) do
    {:reply,state,state}
  end

  def handle_info(:kill_process, state) do
    {:stop, :normal, state}
  end

  def terminate(_reason, _name) do
      #IO.inspect ("Exiting worker: #{name}")
  end

  def init(list) do
    {:ok,list}
  end

  defp via_tuple(x) do
    {:via, Registry, {:my_registry, x}}      #returns pid of a process with that id
  end

end
