pragma solidity ^0.4.13;

contract Token {
    function transfer(address to, uint256 value) returns (bool) {}
    function transferFrom(address from, address to, uint256 value) returns (bool) {}
}

contract FlexDeal {
    address erc20 = ; //Enter an ERC20 address here.

    struct dealStruct {
    	uint payment; /* How much the payment is for the provider is offering? */
        uint sCollateral; /* What the seeker offers as protection... */
        uint pCollateral; /* What the provider offers as protection... */
        address seeker; /* Address of the seeker. */
        bool sConfirmed;
        address provider; /* Address of the provider. */
        bool pConfirmed;
        address arbitrator; /* Address of the arbitrator. */
        uint8 state; /* State of the deal.
        		        State 0 is prefunded.
                        State 1 is funded.
                        State 2 is confirmed.
                        State 3 is disputed.
                        State 4 is send to seeker.
                        State 5 is send to provider.
                        State 6 is mass refund.
                     */
        uint balance;
        mapping (address => uint) paymentLog;
    }
    address[][] whoHasPaid;
    dealStruct[] deals;

	function getDealMoney(uint deal) constant returns (uint, uint, uint, uint) {
		return (deals[deal].payment, deals[deal].sCollateral, deals[deal].pCollateral, deals[deal].balance);
	}
	function getDealPeople(uint deal) constant returns (address, address, address) {
		return (deals[deal].seeker, deals[deal].provider, deals[deal].arbitrator);
	}
	function getDealStates(uint deal) constant returns (uint8, bool, bool) {
		return (deals[deal].state, deals[deal].sConfirmed, deals[deal].pConfirmed);
	}
	function getInvolvement(uint deal, address who) constant returns (uint) {
		return deals[deal].paymentLog[who];
	}
	
    event dealCreated(uint id);
    function newDeal(uint payment, uint seekerCollateral, uint providerCollateral, address seeker, address provider, address arbitrator) {
        deals.push(dealStruct(payment, seekerCollateral, providerCollateral,
		    seeker, false,
			provider, false,
			arbitrator,
			0, 0));
		whoHasPaid.length = whoHasPaid.length + 1;
        dealCreated(deals.length - 1);
    }

    function fundDeal(uint deal, uint howMuch) {
        if (deals[deal].state != 0) {
            return;
        }

        if (Token(erc20).transferFrom(msg.sender, this, howMuch) == false) {
            return;
        }

        deals[deal].balance = deals[deal].balance + howMuch;
        deals[deal].paymentLog[msg.sender] += howMuch;
		whoHasPaid[deal].length = whoHasPaid[deal].length + 1;
        whoHasPaid[deal].push(msg.sender);
    }

    function refund(uint deal) {
        if (deals[deal].state != 0) {
            return;
        }

        deals[deal].balance -= deals[deal].paymentLog[msg.sender];
        Token(erc20).transfer(msg.sender, deals[deal].paymentLog[msg.sender]);
        deals[deal].paymentLog[msg.sender] = 0;
    }

    function setState(uint deal, uint8 state) {
        if ((deals[deal].state == 2) || (deals[deal].state > 3)) { //If the deal is over
            return;
        }

        if (state < 4) {
            if ((msg.sender != deals[deal].seeker) && (msg.sender != deals[deal].provider)) {
                return;
            }

            if (state == 1) {
                if (deals[deal].balance < (deals[deal].payment + deals[deal].sCollateral + deals[deal].pCollateral)) {
                    return;
                }
                deals[deal].state = state;
                return;
            }

            if ((state == 2) && (deals[deal].state == 1)) {
                if (msg.sender == deals[deal].seeker) {
                    deals[deal].sConfirmed = true;
                } else {
                    deals[deal].pConfirmed = true;
                }
                if (deals[deal].sConfirmed && deals[deal].pConfirmed) {
                    Token(erc20).transfer(deals[deal].provider, deals[deal].balance - deals[deal].sCollateral);
                    Token(erc20).transfer(deals[deal].seeker, deals[deal].sCollateral);
					deals[deal].state = state;
                }
            }

            if ((state == 3) && (deals[deal].state == 1)) {
                deals[deal].balance = deals[deal].balance - (deals[deal].sCollateral + deals[deal].pCollateral);
                deals[deal].state = state;
                return;
            }
        }

        if (3 < state && state < 7) {
            if ((deals[deal].state != 3) || (deals[deal].arbitrator != msg.sender)) { //Make sure we're working with a disputed deal and this judgement is from the arbitrator.
                return;
            }

            if (state == 4) {
                Token(erc20).transfer(deals[deal].seeker, deals[deal].balance + deals[deal].sCollateral);
                Token(erc20).transfer(deals[deal].arbitrator, deals[deal].pCollateral);
                deals[deal].state = state;
                return;
            }

            if (state == 5) {
                Token(erc20).transfer(deals[deal].provider, deals[deal].balance + deals[deal].pCollateral);
                Token(erc20).transfer(deals[deal].arbitrator, deals[deal].sCollateral);
                deals[deal].state = state;
                return;
            }

            if (state == 6) {
                for (uint i = 0; i < whoHasPaid[deal].length; i++) {
                    if (((deals[deal].paymentLog[whoHasPaid[deal][i]] / (deals[deal].balance + deals[deal].sCollateral + deals[deal].pCollateral)) * deals[deal].balance) > deals[deal].balance) {
                        Token(erc20).transfer(whoHasPaid[deal][i], deals[deal].balance);
                        Token(erc20).transfer(deals[deal].arbitrator, deals[deal].sCollateral + deals[deal].pCollateral);
                        return;
                    }
                    Token(erc20).transfer(whoHasPaid[deal][i], ((deals[deal].paymentLog[whoHasPaid[deal][i]] / (deals[deal].balance + deals[deal].sCollateral + deals[deal].pCollateral)) * deals[deal].balance));
                    deals[deal].balance = deals[deal].balance - ((deals[deal].paymentLog[whoHasPaid[deal][i]] / (deals[deal].balance + deals[deal].sCollateral + deals[deal].pCollateral)) * deals[deal].balance);
                }
                deals[deal].state = state;
		        return;
            }
        }
        return;
    }
}
