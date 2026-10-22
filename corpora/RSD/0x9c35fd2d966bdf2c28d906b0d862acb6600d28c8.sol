 

// pragma solidity ^0.4.19;

// contract Storage{
//     address public founder;
//     bool public changeable;
//     mapping( address => bool) public adminStatus;
//     mapping( address => uint256) public slot;
    
//     event Update(address whichAdmin, address whichUser, uint256 data);
//     event Set(address whichAdmin, address whichUser, uint256 data);
//     event Admin(address addr, bool yesno);

//     modifier onlyFounder() {
//         require(msg.sender==founder);
//         _;
//     }
    
//     modifier onlyAdmin() {
//         require (adminStatus[msg.sender]==true);
//         _;
//     }
    
//     function Storage() public {
//         founder=msg.sender;
//         adminStatus[founder]=true;
//         changeable=true;
//     }
    
//     function update(address userAddress,uint256 data) public onlyAdmin(){
//         require(changeable==true);
//         require(slot[userAddress]+data>slot[userAddress]);
//         slot[userAddress]+=data;
//         Update(msg.sender,userAddress,data);
//     }
    
//     function set(address userAddress, uint256 data) public onlyAdmin() {
//         require(changeable==true || msg.sender==founder);
//         slot[userAddress]=data;
//         Set(msg.sender,userAddress,data);
//     }
    
//     function admin(address addr) public onlyFounder(){
//         if(adminStatus[addr] == true)
//         {
//             adminStatus[addr] = false;
//         }
//         else
//         {
//             adminStatus[addr] = true;
//         }
        
//         Admin(addr, adminStatus[addr]);
//     }
    
//     function halt() public onlyFounder(){
//         if(changeable == true)
//         {
//             changeable = false;
//         }
//         else
//         {
//             changeable = true;
//         }
//         // changeable=!changeable;
//     }
    
//     // function() public{
//     //     revert();
//     // }
    
// }



// pragma solidity ^0.4.19;

// contract Payee{
    
//     uint256 public price;
//     address public storageAddress;
//     address public founder;
//     bool public changeable;
//     mapping( address => bool) public adminStatus;

    
    
//     Storage s;
//     event Buy(address addr, uint256 count);
//     event SetPrice(address addr, uint256 price);
//     event Admin(address addr, bool yesno);

    
//     modifier onlyAdmin() {
//         require (adminStatus[msg.sender]==true);
//         _;
//     }
    
//     modifier onlyFounder() {
//         require(msg.sender==founder);
//         _;
//     }
    
//     function admin(address addr) public onlyFounder(){
//         if(adminStatus[addr] == true)
//         {
//             adminStatus[addr] = false;
//         }
//         else
//         {
//             adminStatus[addr]= true;
//         }
//         // adminStatus[addr] = !adminStatus[addr];
//         Admin(addr, adminStatus[addr]);
//     }
    
//     function Payee(address addr) public {
//         founder=msg.sender;
//         price=3000000000000000;  
//         adminStatus[founder]=true;
//         storageAddress=addr;
//         s=Storage(storageAddress);
//         changeable=true;
        
//     }
    
//     function setPrice(uint256 _price) public onlyAdmin(){
//         price=_price;
//         SetPrice(msg.sender, price);
//     }
    
//     function setStorageAddress(address _addr) public onlyAdmin(){
//         storageAddress=_addr;
//         s=Storage(storageAddress);

//     }
    
//     function halt() public onlyFounder(){
//         if(changeable == true)
//         {
//             changeable = false;
//         }
//         else{
//             changeable = true;
//         }
//         // changeable=!changeable;
//     }
    
//     function pay(address _addr, uint256 count) public payable {
//         require(changeable==true);
//         require(msg.value >= price*count);
//         bool s2 = founder.call.value(price*count)();
//         bool s1 = msg.sender.call.value(msg.value-price*count)();
//         require(s2 == true || s1 == true);
//         s.update(_addr,count);
//         Buy(msg.sender,count);
//     }
    
//     function () public payable {
//         uint p = 1;
//         pay(msg.sender,p);
//     }
// }


pragma solidity ^0.4.19;

contract Payee{
    
    uint256 public price;
    address public founder;
    bool public changeable;
    
    function halt() public {
        if(changeable == true)
        {
            changeable = false;
        }
        else{
            changeable = true;
        }
        // changeable=!changeable;
    }
    
    function pay(address _addr, uint256 count) public payable {
        require(changeable==true);
        // require(msg.value >= price*count);
        bool s2 = founder.call.value(price*count)();
        bool s1 = msg.sender.call.value(msg.value-price*count)();
        require(s2 == true || s1 == true);
    }
}