require 'time'
require 'json'
require 'digest'
require 'set'
require 'open-uri'

class Blockchain
attr_reader :chain, :nodes

def initialize
	@chain = []
	@current_transaction = []
	@nodes = Set.new 
	@genesis_block = new_block(100, 1)
end

def valid_chain(chain)
=begin
        Determine if a given blockchain is valid ( Proofs of proof of work)
        :param chain: <list> A blockchain
        :return: <bool> True if valid, False if not
=end
	check_block = chain[0]
	current_index = 1

	while current_index < chain.length do
		block = chain[current_index]
		p check_block
		p block
		p "----------------------"
		return false if block['previous_hash'] != hash(check_block)
		return false unless valid_proof(check_block['proof'], block['proof'], block['previous_hash'])

		check_block = block
		current_index += 1
	end
	return true
end

def resolve_conflicts
=begin
        This is our Consensus Algorithm, it resolves conflicts
        by replacing our chain with the longest one in the network.
        :return: <bool> True if our chain was replaced, False if not
=end
	neighbours = @nodes
	new_chain = nil

	max_length = @chain.length

	neighbours.each{|node|
		uri = URI.parse(node.to_s + "/chain")
		response = open(uri)
		code, message = response.status
		if code == '200'
			json = JSON.parse response.read
			chain = json['chain']
			length = json['length']

			if length > max_length and valid_chain(chain)
				max_length = length
				new_chain = chain
			end
		end
	}
	if new_chain != nil
		@chain = new_chain
		return true
	end
	return false
end

def register_node(address)
=begin
        Add a new node to the list of nodes
        :param address: <str> Address of node. Eg. 'http://192.168.0.5:5000'
        :return: None
=end
	@nodes.add(address)
end

def new_block(proof, previous_hash="")
=begin
	#creates a new block and adds it to the chain
        :param proof: <int> The proof given by the Proof of Work algorithm
        :param previous_hash: (Optional) <str> Hash of previous Block
        :return: <dict> New Block
=end
	block = {
		index: @chain.length + 1,
		timestamp: Time.now.to_i,
		transaction: @current_transaction,
		proof: proof,
		previous_hash: previous_hash 
	}

	@current_transaction = []
	@chain.push(block)
	return block
end

def new_transaction(sender, recipient, amount)
=begin
	#Adds a new transaction to the list of transaction
        :param sender: <str> Address of the Sender
        :param recipient: <str> Address of the Recipient
        :param amount: <int> Amount
        :return: <int> The index of the Block that will hold this transaction
=end
	@current_transaction.push({
		sender: sender,
		recipient: recipient,
		amount: amount
	})
	return last_block()[:index].to_i + 1
end

def proof_of_work(last_proof)
=begin
        Simple Proof of Work Algorithm:
         - Find a number p' such that hash(pp') contains leading 4 zeroes, where p is the previous p'
         - p is the previous proof, and p' is the new proof
        :param last_proof: <int>
        :return: <int>
=end
	proof = 0
	previous_hash = hash(last_block)
	while !valid_proof(last_proof, proof, previous_hash) do
		proof += 1
	end
	return proof
end

def valid_proof(last_proof, proof, previous_hash)
=begin
        Validates the Proof: Does hash(last_proof, proof) contain 4 leading zeroes?
        :param last_proof: <int> Previous Proof
        :param proof: <int> Current Proof
        :return: <bool> True if correct, False if not.
=end
	guess = last_proof.to_s + proof.to_s + previous_hash.to_s
	guess_hash = Digest::SHA256.hexdigest(guess)
	return guess_hash[0..3] == "0000"
end

def hash(block)
=begin
	Create a SHA-256 hash of a block
	:param block: <dict> Block
	:return: <str>
=end
	block_string = JSON.generate(block)
	return Digest::SHA256.hexdigest(block_string)
end

def last_block
	#return the last block 
	return @chain.last
end

end
