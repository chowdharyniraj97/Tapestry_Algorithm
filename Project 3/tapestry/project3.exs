defmodule  Project3 do
  def start do
    numNodes=String.to_integer(Enum.at(System.argv(),0))
    numRequest=String.to_integer(Enum.at(System.argv(),1))
    Tapestry.fire(numNodes,numRequest)
  end
end

Project3.start
