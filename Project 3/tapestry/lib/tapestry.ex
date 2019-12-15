defmodule Tapestry do

  def fire(numNodes,numRequest) do
    Registry.start_link(name: :my_registry, keys: :unique)
    :ets.new(:mapping, [:set, :public, :named_table])
    :ets.new(:result, [:set, :public, :named_table])
    if(numNodes<=20) do
      Enum.map(1..numNodes, fn(x)-> start_node(x) end)
      Enum.map(1..numNodes, fn(y)-> set_neigh(y,numNodes) end)
      printftable(numNodes)
    else
      Enum.map(1..numNodes-20, fn(x)-> start_node(x) end)
      Enum.map(1..numNodes-20, fn(y)-> set_neigh(y,numNodes-20) end)
     # IO.puts "Created #{numNodes-20} nodes"
      #IO.puts "Routing tables-"
      printftable(numNodes-20)
     # IO.puts("Creating remaining 20 nodes")
      Enum.map(numNodes-19..numNodes, fn(x)-> start_node(x) end)
      Enum.map(1..numNodes, fn(y)-> set_neigh(y,numNodes) end)
      #IO.puts "Created remaining 20 nodes"
      #IO.puts "Routing tables of entire network-"
      printftable(numNodes)
    end
    _hops=[-1]
    hops=Enum.map(1..numNodes,fn(a) ->
     p= Enum.map(1..numRequest, fn(_b)->
        random_number = :rand.uniform(numNodes)
        
          if(random_number != a) do
            route(a,random_number,0,numNodes)
            
          end
         
         
          	

        #IO.puts "Maximum hops for #{a} to #{random_number} = #{hops}"
      end)
     find_max(p,-1)
    end)
    #IO.inspect hops
    
    
    max_hops=find_max(hops,-1)
    IO.puts max_hops 
  end
def find_max([],max)do
  max;
end


def find_max(list,max) do
  [head|tail]=list;
  cond do
    head==nil->find_max(tail,max)

    head>max->find_max(tail,head)

    true->find_max(tail,max)

  end
    
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

  def route(c,d,hops,numNodes) do
    [{_,hash_origin}]= :ets.lookup(:mapping,c)
    [{_,hash_dest}]= :ets.lookup(:mapping,d)
    #IO.inspect "#{hash_origin} #{hash_dest}"
    count=check(hash_origin,hash_dest,0)
    pos = String.at(hash_dest,count)
    pos = String.to_integer(pos,16)
    origin=GenServer.call(via_tuple(c), :print, :infinity)
    s_table=Enum.at(origin,1)

    a = Map.get(s_table,{count,pos})
    #IO.inspect "#{a}"
    if (Enum.at(a,0) == hash_dest) do
      hops
    else
      [{_,ans}]=:ets.lookup(:mapping,Enum.at(a,0))
      route(ans,d,hops+1,numNodes)
    end
  end

  def printftable(numNodes) do
    Enum.map(1..numNodes, fn(z)->
      k = GenServer.call(via_tuple(z),:print)
      k = Enum.at(k,1)
      Enum.reduce(0..7, %{}, fn x, acc ->
        Enum.reduce(0..15, acc, fn y, _acc ->
          l=Map.get(k, {x, y})
          if(l != []) do
          #  IO.puts "For id = #{z}: row = #{x}, column = #{y} and value = #{l}"
          end
        end)
      end)
    end)
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

  def handle_call(:print,_,state) do
    {:reply,state,state}
  end

  def init(list) do
    {:ok,list}
  end

  defp via_tuple(x) do
    {:via, Registry, {:my_registry, x}}      #returns pid of a process with that id
  end

end
