## Tapestry Algorithm
	
## Project compiled by
	Akash Jajoo
	Niraj Chowdhary

## Steps to execute
1. Extract Tapestry_Algorithm to you local machine
2. Go to Project 3/tapestry folder via command prompt
3.  Type **mix run proj3.exs arg1 arg2** 
  Here,
     **arg1** is the number of nodesinvolved
      **arg2** Number of request per node.  
    **Output:**  Maximum number of hops taken to find the requested file.
    
 
## Tapestry algorithm
1. Here every node in the network has their own 16 bit long identifier
2. Each node maintains a finger table which is the key value pair, just like hash map, that points to the neighbours it knows about.
3. Neighbour is selected on basis of prefix matching, whichever has the longest prefix matching is chosen as the next node to hop to.
4. The above proecess continues until desired object is found and it takes O(logn) time.


## Output:
[![Capture.png](https://i.postimg.cc/jjGfqsv2/Capture.png)](https://postimg.cc/xk38tVwV)


The above screenshot demonstrates the working output of 100 and 1000 nodes handling 2 requests per node. 
For 100 nodes the maximum hops is 2 to find an object
Likewise for 1000 it is 4.
