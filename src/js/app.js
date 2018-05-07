App = {
  web3Provider: null,
  contracts: {},

  init: function() {
    return App.initWeb3();
  },

  initWeb3: function() {
    // Initialize web3 and set the provider to the testRPC.
    if (typeof web3 !== 'undefined') {
      App.web3Provider = web3.currentProvider;
      web3 = new Web3(web3.currentProvider);
    } else {
      // set the provider you want from Web3.providers
      App.web3Provider = new Web3.providers.HttpProvider('http://127.0.0.1:9545');
      web3 = new Web3(App.web3Provider);
    }

    return App.initContracts();
  },

  initContracts: function() {
    $.getJSON('contract.json', function(data) {
      // Get the necessary contract artifact file and instantiate it with truffle-contract.
      var contractArtifact = data;
      App.contracts[contractArtifact.contractName] = TruffleContract(contractArtifact);

      // Set the provider for our contract.
      App.contracts[contractArtifact.contractName].setProvider(App.web3Provider);

      App.createContractFunctions(contractArtifact);
    });
  },

  createContractFunctions: function(contractData) {
    if(!contractData.abi) {
      // No functions for this contract
      return;
    }

    for (var i = 0; i < contractData.abi.length; i++) {
      let functionObj = contractData.abi[i];
      if (functionObj.type !== "function") {
        // Only process functions
        continue;
      }

      App.createContractFunction(contractData, functionObj);      
    }
    // TODO: add default function to list

  },

  createContractFunction: function(contractData, functionObj) {
    let $parentDiv = $('<div/>', {
      id: functionObj.name
    });
    // Create Action Button
    let $button = $('<button/>', { 
        text: functionObj.name,
        id: 'btn_' + functionObj.name,
        click: function () {
          let contract = App.contracts[contractData.contractName];
          contract.deployed().then(function(instance) {
            return instance[functionObj.name](App.getContractFunctionArgumentValues(functionObj));
          }).then(function(result) {
            balance = web3.toBigNumber(result);
            $('#output_' + functionObj.name).text(balance);
          }).catch(function(err) {
            console.log(err.message);
          });
        }
      });
    // Create all argument inputs
    let argumentInputs = App.createContractFunctionArguments(functionObj, $parentDiv);
    // Create output text
    let $output = $('<span/>', {
      id: 'output_' + functionObj.name
    });
    $parentDiv.append($button).append(argumentInputs).append($output);

    $('#functions').append($parentDiv);
  },

  createContractFunctionArguments: function(functionObj) {
    let $argDiv = $('<div/>', {
      id: 'arguments_' + functionObj.name
    });
    // Create all custom argument inputs
    for (var i = 0; i < functionObj.inputs.length; i++) {
      let inputObj = functionObj.inputs[i];
      let $input = $('<input/>', { 
          type: 'text',
          placeholder: inputObj.name,
          id: 'input_' + inputObj.name
        });
      $argDiv.append($input);
    }
    // Create default amount input if function is payable
    if (functionObj.payable) {
      let $input = $('<input/>', { 
          type: 'text',
          placeholder: 'amount',
          id: 'input_' + functionObj.name + '_amount'
        });
      $argDiv.append($input);
    }

    return $argDiv;
  },

  getContractFunctionArgumentValues: function(functionObj) {
    let values = {};
    // Get all custom argument values
    for (var i = 0; i < functionObj.inputs.length; i++) {
      let inputObj = functionObj.inputs[i];
      values[inputObj.name] = $('#input_' + inputObj.name).val();
    }
    // Get default amount input if function is payable
    if (functionObj.payable) {
      let inputObj = functionObj.inputs[i];
      let valueInEth = web3.toWei($('#input_' + functionObj.name + '_amount').val(), 'ether');
      values['value'] = valueInEth;
    }
    return values;
  }

};

$(function() {
  $(window).load(function() {
    App.init();
  });
});
