pragma solidity ^0.4.13;

contract Postman {
    struct data{address home; uint256 value; uint256 reward;bool delivered;}
    address private owner;
    uint public fee;
    uint public fee2;
    uint256 private balance;
    data[] private que;
    uint[] private undelivered;
    event Report(string message,uint index);
    function Postman(){owner = msg.sender;fee = 2;fee2=50;balance=0;}
    function()payable{revert();}
    function draw(){if(balance > 0){owner.transfer(balance);balance-=balance;}}
    function mails_to_deliver()constant returns(uint[]){return undelivered;}
    function get_mail(uint index)constant returns(uint256){return que[index].reward;}
    function update_fee(uint new_fee,uint new_fee2){require(msg.sender == owner);fee = new_fee;fee2 =new_fee2;}
    function post (address x,uint percent) payable 
        {
            require(msg.value > 0 && percent >= 1 && percent <= 1000 );
            balance += (msg.value * fee)/100;
            que.push(data({delivered:false,home:x,reward:((msg.value - (msg.value * fee)/100) * percent)/1000,value: msg.value - (msg.value * fee)/100 - (((msg.value - (msg.value * fee)/100) * percent)/1000)}));
            undelivered.push(1);
        } 
    function deliver(uint index,uint direct)
        {
            require(undelivered[index] > 0);
            W w;
            //  = new W();
            w.boom.value(que[index].value)(que[index].home);
            if((que[index].reward * 2) > msg.gas && direct == 1){this.post.value(que[index].reward)(msg.sender,fee2);}
            else{msg.sender.transfer(que[index].reward);}
            Report("Message Delivered:",index);
            delete undelivered[index];
            delete que[index];
        }
}

contract W{function W(){}function boom(address x)payable{selfdestruct(x);}}