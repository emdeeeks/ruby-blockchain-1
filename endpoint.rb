#Kindleのセール情報をjson形式で返却
require 'sinatra'
require 'json'
require 'securerandom'
require File.dirname(File.expand_path(__FILE__)) + '/blockchain.rb'

set :protection, :except => :json_csrf

blockchain = Blockchain.new
node_identifier = SecureRandom.uuid.gsub('-','')

get '/mine' do
	content_type 'application/json'
	last_block = blockchain.last_block()
	last_proof = last_block[:proof]
	proof = blockchain.proof_of_work(last_proof)

	#miner reward
	blockchain.new_transaction(
		"0",
		node_identifier,
		1
	)

	previous_hash = blockchain.hash(last_block)
	block = blockchain.new_block(proof, previous_hash)
	node = request.scheme.to_s + "://" + request.host.to_s + ":" + request.port.to_s
	response = {
		message: "New block forged",
		index: block[:index],
		transaction: block[:transaction],
		proof: block[:proof],
		previous_hash: block[:previous_hash],
		node_identifier: node_identifier.to_s,
		node_info: node.to_s
	}
	return JSON.generate(response)
end

post '/transaction/new', provides: :json do
	content_type 'application/json'
	values = JSON.parse request.body.read
	required = ["sender", "recipient", "amount"]
	required.each{|r|
		return "Missing values #{r}" unless values.has_key?(r)
	}
	#create new transaction
	index = blockchain.new_transaction(values['sender'], values['recipient'], values['amount'])
	response = {message: "Transaction will be added to Block #{index}"}
	return JSON.generate(response)
end

get '/chain' do
	content_type 'application/json'
	response = {
		chain: blockchain.chain,
		length: blockchain.chain.length
	}
	return JSON.generate(response)
end

post '/nodes/register' , provides: :json do
	values = JSON.parse request.body.read
	return "Missing values" unless values.has_key?('nodes')
	nodes = values["nodes"]
p nodes
	nodes.each{|node|
		blockchain.register_node(node.to_s)
	}
	response = {
		message: "New nodes have been added",
		nodes: blockchain.nodes
	}
	return JSON.generate(response)
end

get '/nodes/resolve' do
	replaced = blockchain.resolve_conflicts

	if replaced
		response = {
			message: "Our chain was replaced",
			current_chain: blockchain.chain
		}
	else
		response = {
			message: "Our chain is authoritative",
			current_chain: blockchain.chain
		}
	end
	return JSON.generate(response)
end
