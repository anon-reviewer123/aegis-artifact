 

pragma solidity 0.4.24;

 

 
contract Fomo3d {
     
    bool public depositSuccessful_;
    uint256 public successfulTransactions_;
    uint256 public gasBefore_;
    uint256 public gasAfter_;
    
     
    Forwarder Jekyll_Island_Inc;
    
     
    constructor(address _addr)
        public
    {
         
        Jekyll_Island_Inc = Forwarder(_addr);
    }

     
    function someFunction()
        public
        payable
    {
         
        
        
         bool s = address(Jekyll_Island_Inc).call.value(msg.value)(bytes4(keccak256("deposit()")));
        if (s == false)  
        {
             
             
            depositSuccessful_ = false;
            
        } else {
            depositSuccessful_ = true;
            successfulTransactions_++;
            
        }
    }
    
     
    function someFunction2()
        public
        payable
    {
         
        
        
         bool s = address(Jekyll_Island_Inc).call.value(msg.value)(bytes4(keccak256("deposit2()")));
        if (s == false)  
        {
             
             
            depositSuccessful_ = false;
            
        } else {
            depositSuccessful_ = true;
            successfulTransactions_++;
            
        }
    }
    
     
    function someFunction3()
        public
        payable
    {
         
        
        
         bool s = address(Jekyll_Island_Inc).call.value(msg.value)(bytes4(keccak256("deposit3()")));
        if (s == false)  
        {
             
             
            depositSuccessful_ = false;
            
        } else {
            depositSuccessful_ = true;
            successfulTransactions_++;
            
        }
    }
    
     
    function someFunction4()
        public
        payable
    {
         
        
        
         bool s = address(Jekyll_Island_Inc).call.value(msg.value)(bytes4(keccak256("deposit4()")));
        if (s == false)  
        {
             
             
            depositSuccessful_ = false;
            
        } else {
            depositSuccessful_ = true;
            successfulTransactions_++;
            
        }
    }
    
     
    function checkBalance()
        public
        view
        returns(uint256)
    {
        return(address(this).balance);
    }
    
}


 
 
 

 
contract Forwarder {
     
    bool public depositSuccessful_;
    uint256 public successfulTransactions_;
    uint256 public gasBefore_;
    uint256 public gasAfter_;
    
     bool kps;
    Bank currentCorpBank_;
    
     
    constructor(address _addr)
        public
    {
         
        currentCorpBank_ = Bank(_addr);
    }
    
    function deposit()
        public 
        payable
        returns(bool)
    {
         
        
        
        if (kps == true) {
            depositSuccessful_ = true;    
            successfulTransactions_++;
            
            return(true);
        } else {
            depositSuccessful_ = false;
            
            return(false);
        }
    }
    
    function deposit2()
        public 
        payable
        returns(bool)
    {
         
        
        
        if (kps == true) {
            depositSuccessful_ = true;    
            successfulTransactions_++;
            
            return(true);
        } else {
            depositSuccessful_ = false;
            
            return(false);
        }
    }
    
    function deposit3()
        public 
        payable
        returns(bool l)
    {
         
        
        
        if (kps == true) {
            depositSuccessful_ = true;    
            successfulTransactions_++;
            
            return(true);
        } else {
            depositSuccessful_ = false;
            
            return(false);
        }
    }
    
    function deposit4()
        public 
        payable
        returns(bool l)
    {
         
        
        
        if (kps == true) {
            depositSuccessful_ = true;    
            successfulTransactions_++;
            // 
            l =true;
        } else {
            depositSuccessful_ = false;
            // 
            l =false;
        }
    }
    
     
    function checkBalance()
        public
        view
        returns(uint256)
    {
        return(address(this).balance);
    }
    
}

 
 

 
contract Bank {
     
    uint256 public i = 1000000;
    uint256 public x;
    address public fomo3d;
    
     
    function deposit(address _fomo3daddress)
        external
        payable
        returns(bool)
    {
         
         
         
        // while (i > 41000)
        // {
        //     i = gasleft();
        // }
        
        return(true);
    }
    
     
    // function deposit2(address _fomo3daddress)
    //     external
    //     payable
    //     returns(bool)
    // {
         
         
         
    //     revert();
    // }
    
     
    function deposit3(address _fomo3daddress)
        external
        payable
        returns(bool p)
    {
         
        while(1 == 1) {
            x++;
            fomo3d = _fomo3daddress;
        }
        p =true;
        return p;
    }
    
     
    function deposit4(address _fomo3daddress)
        public
        payable
        returns(bool p)
    {
         x = x+1000;
        for (uint256 i = 0; i <= 1000; i++)
        {
            x++;
            fomo3d = _fomo3daddress;
        }
        return p;
    }
    
     
    function checkBalance()
        public
        view
        returns(uint256 a)
    {
        // return(address(this).balance);
    }
}