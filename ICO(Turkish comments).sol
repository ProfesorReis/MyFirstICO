// SPDX-License-Identifier: Unlicansed
pragma solidity ^0.8.7;

// ----------------------------------------------------------------------------
// EIP-20: ERC-20 Token Standard
// https://eips.ethereum.org/EIPS/eip-20
// ----------------------------------------------------------------------------

// ERC20 = Ethereum Request Command, Ethereum ağına bağlı tokenler için kullanılıyor
// 6 "Function" ve 2 "Event" içeren bir "interface" barındırıyor. Kontratı yazarken bu fonksiyonları "override" etmemiz gerekiyor.
// Transfer edilebilir bir token için hepsini kullanmaya gerek yok ilk üç fonksiyon yeterli?
// https://ethereum.org/en/developers/docs/standards/tokens/erc-20/ Sitede 3 adet isteğe bağlı fonksiyon daha var?

interface ERC20Interface {

    function totalSupply() external view returns (uint256);
    function balanceOf(address _owner) external view returns (uint256 balance);
    function transfer(address _to, uint256 _value) external returns (bool success);

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function approve(address _spender, uint256 _value) external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

}

// Hata almamak için interface'de tanımlı olan her şeyi "override" etmemiz gerekiyor?
// "virtual" fonksiyona eklendiğinde yeni kontratta davranışı değişebilir demek?
// Burdaki çoğu şey standart ve anlamama gerek yok sadece böyle yapıldığını bilmek gerekiyor.
contract MyFirstToken is ERC20Interface {

    string public name = "MyFirstERC20Token";
    string public symbol = "MFET";
    uint public decimals = 0;   // Token için virgülden sonra gelen max sayı sayısı? Genelde 18 oluyor.
    uint public override totalSupply;   // "totalSupply" için fonksiyon tanımlamak yerine böyle yaptık

    address public founder; // Tokenlerin ilk başta gideceği adresi tanımladık. Zorunlu değil ama kullanışlı?
    mapping(address => uint) public balances;   // Her adreste varsayılan olarak 0 token tanımlı oluyor. Hangi adreste ne kadar token var depolayabilmek için tanımlıyoruz.

    // Kendi hesabındaki tokenlerin bir kısmını başkasının harcamasına izin vermek?
    mapping(address => mapping(address => uint)) allowed;
    // 0x111... (owner) allows 0x222... (the spender) --- 100 tokens
    // allowed[0x111][0x222] = 100;

    constructor() {
        totalSupply = 1000000;
        founder = msg.sender;
        balances[founder] = totalSupply;    // Bütün tokenleri "founder" a aktardık.
    }

    // Herhangi bir adresin elinde kaç token var görmek için kullanılan fonksiyon.
    function balanceOf(address _owner) public view override returns (uint256 balance) {
        return balances[_owner];
    }

    // Transfer yapmak için gereken fonksiyon.
    function transfer(address _to, uint256 _value) public virtual override returns (bool success) {
        require(balances[msg.sender] >= _value);    // Elinde bulunan tokenden fazla token göderememesi için

        balances[_to] += _value;
        balances[msg.sender] -= _value;
        emit Transfer(msg.sender, _to, _value);

        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public virtual override returns (bool success) {
        require(allowed[_from][_to] >= _value);
        require(balances[_from] >= _value);

        balances[_from] -= _value;
        balances[_to] += _value;
        allowed[_from][_to] -= _value;

        return true;
    }

    function approve(address _spender, uint256 _value) public override returns (bool success) {
        require(balances[msg.sender] >= _value);
        require(_value > 0);

        allowed[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public override view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

}



contract MyFirstTokenICO is MyFirstToken {

    address public admin;
    address payable public deposit; // Ether'ler kontrata kontrattan da deposit adresine gidicek. Bu şekilde daha güvenliymiş.
    uint tokenPrice = 0.001 ether;  // 1 Ether = 1000 MFET
    uint public hardCap = 300 ether;    // Maksimum bağış sayısı
    uint public raisedAmount;
    uint public saleStart = block.timestamp;    // Deploy eder etmez başlar.
    uint public saleEnd = block.timestamp + 60480;  // Deploy ettikten 60480 saniye sonra bitecek.
    uint public tokenTradeStart = saleEnd + 60480;  // Satış bittikten 60480 saniye sonra satılabilir olacak.
    uint public maxInvestment = 5 ether;
    uint public minInvestment = 0.1 ether;

    enum State {beforeStart, running, afterEnd, halted}
    State public icoState;

    constructor(address payable _deposit) {
        deposit = _deposit;
        admin = msg.sender;
        icoState = State.beforeStart;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    // ICO'yu durdurmak veya devam ettirmek için kullanılacak fonksiyonlar.
    function halt() public onlyAdmin {
        icoState = State.halted;
    }
    function resume() public onlyAdmin {
        icoState = State.running;
    }

    function changeDeposit(address payable _newDeposit) public onlyAdmin {
        deposit = _newDeposit;
    }

    // ICO'nun şu anki durumunuu gösteren fonksiyon.
    function getCurrentState() public view returns(State) {
        if(icoState == State.halted) {
            return State.halted;
        } else if(block.timestamp < saleStart) {
            return State.beforeStart;
        } else if(block.timestamp >= saleStart && block.timestamp <= saleEnd) {
            return State.running;
        } else {
            return State.afterEnd;
        }
    }

    event Invest(address investor, uint value, uint tokens);

    // Yatırım yapmak için kullanılacak fonksiyon.
    function invest() payable public returns(bool) {
        icoState = getCurrentState();
        require(icoState == State.running);

        require(msg.value >= minInvestment && msg.value <= maxInvestment);
        raisedAmount += msg.value;
        require(raisedAmount <= hardCap);

        uint tokens = msg.value / tokenPrice;

        balances[msg.sender] += tokens;
        balances[founder] -= tokens;
        deposit.transfer(msg.value);    //  Yatırım yapılan miktarı deposit adresine gönderen kod.
        emit Invest(msg.sender, msg.value, tokens);

        return true;
    }

    // Birisi kontrat adresine direkt olarak para yolladığında "invest()" fonksiyonu devreye girecek.
    receive() payable external {
        invest();
    }

    // Alttaki iki fonksiyonu tokenleri kilitleyebilmek için çağırdık?
    // "virtual" ı sildik
    function transfer(address _to, uint256 _value) public override returns (bool success) {
        require(block.timestamp > tokenTradeStart);

        // MyFirstToken = Diğer kontratın ismi
        MyFirstToken.transfer(_to, _value);    // soldaki kod ile aynı = super.transfer(_to, _value);
        return true;
    }

    // "virtual" ı sildik
    function transferFrom(address _from, address _to, uint256 _value) public override returns (bool success) {
        require(block.timestamp > tokenTradeStart);

        // MyFirstToken = Diğer kontratın ismi
        MyFirstToken.transferFrom(_from, _to, _value);  // soldaki kod ile aynı = super.transfer(_to, _value);
        return true;
    }
    
}
