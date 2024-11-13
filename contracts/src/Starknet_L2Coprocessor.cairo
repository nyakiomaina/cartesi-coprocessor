%lang starknet

from starkware.starknet.common.syscalls import (
    get_caller_address,
    call_contract
)
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.keccak import (
    keccak,
    compute_kec_hash
)
from starkware.cairo.common.serialize import serialize_word
from starkware.starknet.common.storage import Storage
from starkware.cairo.common.math_utils import assert_not_zero
from starkware.cairo.common.uint256 import Uint256

# Interface for the callback contract
@contract_interface
namespace ICoprocessorCallback:
    func coprocessor_callback_outputs_only(
        machine_hash: felt,
        payload_hash: felt,
        outputs_len: felt,
        outputs: felt*
    ):
    end
end

# Contract definition
@contract
namespace L2Coprocessor:
    # Storage variables
    @storage_var
    func owner() -> (address: felt):
    end

    @storage_var
    func l1_coordinator() -> (address: felt):
    end

    @storage_var
    func responses(response_hash: felt) -> (exists: felt):
    end

    # Events
    @event
    func TaskIssued(machine_hash: felt, input_len: felt, input: felt*, callback: felt):
    end

    @event
    func TaskCompleted(machine_hash: felt, response_hash: felt):
    end

    # Constructor
    @constructor
    func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}():
        let (caller_address) = get_caller_address()
        owner.write(caller_address)
        return ()
    end

    # Modifier equivalent: onlyOwner
    func _only_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}():
        let (caller_address) = get_caller_address()
        let (stored_owner) = owner.read()
        assert caller_address == stored_owner, 'Caller is not the owner'
        return ()
    end

    # setL1Coordinator function
    @external
    func set_l1_coordinator{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _l1_coordinator: felt
    ):
        _only_owner()
        l1_coordinator.write(_l1_coordinator)
        return ()
    end

    # issueTask function
    @external
    func issue_task{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        machine_hash: felt,
        input_len: felt,
        input: felt*,
        callback: felt
    ):
        emit TaskIssued(machine_hash, input_len, input, callback)
        return ()
    end

    # storeResponseHash function (only callable by l1Coordinator via L1 message)
    @l1_handler
    func store_response_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        from_address: felt,
        response_hash: felt,
        machine_hash: felt
    ):
        # Check authorization
        let (l1_coord_address) = l1_coordinator.read()
        assert from_address == l1_coord_address, 'Not authorized'

        # Check if response_hash is already stored
        let (exists) = responses.read(response_hash)
        assert exists == 0, 'Response already whitelisted'

        # Store response_hash
        responses.write(response_hash, 1)

        # Emit event
        emit TaskCompleted(machine_hash, response_hash)
        return ()
    end

    # callbackWithOutputs function
    @external
    func callback_with_outputs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        resp_machine_hash: felt,
        resp_payload_hash: felt,
        resp_output_merkle: felt,
        outputs_len: felt,
        outputs: felt*,
        callback_address: felt
    ):
        let resp_array = [resp_machine_hash, resp_payload_hash, resp_output_merkle]

        let (resp_serialized_len, resp_serialized) = serialize_word(resp_array)
        let (resp_hash) = compute_kec_hash(resp_serialized_len, resp_serialized)

        let (exists) = responses.read(resp_hash)
        assert exists == 1, 'Response not whitelisted'

        # Compute outputsHashes
        alloc_locals
        let outputs_hashes = alloc()
        for i in range(outputs_len):
            let output = outputs[i]
            # Serialize output
            let (output_serialized_len, output_serialized) = serialize_word([output])
            let (output_hash) = compute_kec_hash(output_serialized_len, output_serialized)
            assert outputs_hashes[i] = output_hash
        end

        # Compute Merkle root of outputs_hashes
        let (computed_merkle_root) = compute_merkle_root(outputs_hashes, outputs_len)
        assert resp_output_merkle == computed_merkle_root, 'Invalid Merkle root'

        # Prepare calldata?
        let total_calldata_len = 2 + outputs_len  # resp_machine_hash, resp_payload_hash, outputs
        let calldata_ptr = alloc()
        assert calldata_ptr[0] = resp_machine_hash
        assert calldata_ptr[1] = resp_payload_hash
        for i in range(outputs_len):
            assert calldata_ptr[2 + i] = outputs[i]
        end

        # callback contract
        let (selector) = get_selector('coprocessor_callback_outputs_only')
        let (retdata_size, retdata) = call_contract(
            to_address=callback_address,
            function_selector=selector,
            calldata_size=total_calldata_len,
            calldata=calldata_ptr
        )

        return ()
    end

end
