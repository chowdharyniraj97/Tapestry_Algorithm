defmodule  Project3 do
  def start do
    numNodes=String.to_integer(Enum.at(System.argv(),0))
    numRequest=String.to_integer(Enum.at(System.argv(),1))
    numKill=String.to_integer(Enum.at(System.argv(),2))
    Tapestry.fire(numNodes,numRequest,numKill)
  end
end

Project3.start
