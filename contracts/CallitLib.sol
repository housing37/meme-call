// SPDX-License-Identifier: UNLICENSED
// inherited contracts
// import "@openzeppelin/contracts/utils/Strings.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // deploy
// import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
// import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol"; // deploy

// local _ $ npm install @openzeppelin/contracts
import "./node_modules/@openzeppelin/contracts/utils/Strings.sol";
import "./node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./node_modules/@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "./ICallitLib.sol";

pragma solidity ^0.8.20;

interface IERC20x {
    function decimals() external pure returns (uint8);
}

library CallitLib {
    address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    // address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);
    string public constant tVERSION = '0.35';
    event StepLog(string _descr, uint16 _step, string _data0, string _data1);

    /* -------------------------------------------------------- */
    /* PUBLIC
    /* -------------------------------------------------------- */
    function debug_log_uint(address _sender, uint8 _uint8, uint16 _uint16, uint32 _uint32, uint64 _uint64, uint256 _uint256) external pure {}
    function debug_log_addess(address _sender, address _address0, address _address1, address _address2) external pure {}
    function debug_log_string(address _sender, string calldata _string0, string calldata _string1, string calldata _string2) external pure {}
    
    function grossStableBalance(address[] memory _stables, address _vault, uint8 _usd_decimals) external view returns (uint64) {
        // NOTE: no onlyVault needed, anyone can call this function
        //  ie. simply gets a gross bal of whatever tokens & for whatever addy they want
        uint64 gross_bal = 0;
        for (uint8 i = 0; i < _stables.length;) {
            // NOTE: more efficient algorithm taking up less stack space with local vars
            require(IERC20x(_stables[i]).decimals() > 0, ' found stable with invalid decimals :/ ');
            gross_bal += _uint64_from_uint256(_normalizeStableAmnt(IERC20x(_stables[i]).decimals(), IERC20(_stables[i]).balanceOf(_vault), _usd_decimals));
            unchecked {i++;}
        }
        return gross_bal;
    }
    // NOTE: *WARNING* _stables could have duplicates (from 'whitelistStables' set by keeper)
    function _getStableTokenLowMarketValue(address[] memory _stables, address[] memory _routers) external view returns (address) {
        // traverse _stables & select stable w/ the lowest market value
        uint256 curr_high_tok_val = 0;
        address curr_low_val_stable = address(0x0);
        for (uint8 i=0; i < _stables.length;) {
            address stable_addr = _stables[i];
            if (stable_addr == address(0)) { continue; }

            // get quote for this stable (traverses 'uswapV2routers')
            //  looking for the stable that returns the most when swapped 'from' WPLS
            //  the more USD stable received for 1 WPLS ~= the less overall market value that stable has
            address[] memory wpls_stab_path = new address[](2);
            wpls_stab_path[0] = TOK_WPLS;
            wpls_stab_path[1] = stable_addr;
            (, uint256 tok_val) = _best_swap_v2_router_idx_quote(wpls_stab_path, 1 * 10**18, _routers);
            if (tok_val >= curr_high_tok_val) {
                curr_high_tok_val = tok_val;
                curr_low_val_stable = stable_addr;
            }

            // NOTE: unchecked, never more than 255 (_stables)
            unchecked {
                i++;
            }
        }
        return curr_low_val_stable;
    }
    
    // NOTE: *WARNING* _stables could have duplicates (from 'whitelistStables' set by keeper)
    function _getStableTokenHighMarketValue(address[] memory _stables, address[] memory _routers) external view returns (address) {
        // traverse _stables & select stable w/ the highest market value
        uint256 curr_low_tok_val = 0;
        address curr_high_val_stable = address(0x0);
        for (uint8 i=0; i < _stables.length;) {
            address stable_addr = _stables[i];
            if (stable_addr == address(0)) { continue; }

            // get quote for this stable (traverses 'uswapV2routers')
            //  looking for the stable that returns the least when swapped 'from' WPLS
            //  the less USD stable received for 1 WPLS ~= the more overall market value that stable has
            address[] memory wpls_stab_path = new address[](2);
            wpls_stab_path[0] = TOK_WPLS;
            wpls_stab_path[1] = stable_addr;
            (, uint256 tok_val) = _best_swap_v2_router_idx_quote(wpls_stab_path, 1 * 10**18, _routers);
            if (tok_val >= curr_low_tok_val) {
                curr_low_tok_val = tok_val;
                curr_high_val_stable = stable_addr;
            }

            // NOTE: unchecked, never more than 255 (_stables)
            unchecked {
                i++;
            }
        }
        return curr_high_val_stable;
    }
    // uniswap v2 protocol based: get router w/ best quote in 'uswapV2routers'
    function _best_swap_v2_router_idx_quote(address[] memory path, uint256 amount, address[] memory _routers) public view returns (uint8, uint256) {
        uint8 currHighIdx = 37;
        uint256 currHigh = 0;
        for (uint8 i = 0; i < _routers.length;) {
            uint256[] memory amountsOut = IUniswapV2Router02(_routers[i]).getAmountsOut(amount, path); // quote swap
            if (amountsOut[amountsOut.length-1] > currHigh) {
                currHigh = amountsOut[amountsOut.length-1];
                currHighIdx = i;
            }

            // NOTE: unchecked, never more than 255 (_routers)
            unchecked {
                i++;
            }
        }

        return (currHighIdx, currHigh);
    }
    function _getCallTicketUsdTargetPrice(ICallitLib.MARKET memory _mark, uint16 _tickIdx, uint64 _usdMinTargetPrice, uint8 _usd_decs) external view returns(uint64) {
        address[] memory _resultTickets = _mark.marketResults.resultOptionTokens;
        address[] memory _pairAddresses = _mark.marketResults.resultTokenLPs;
        address[] memory _resultStables = _mark.marketResults.resultTokenUsdStables;

        // exeArbPriceParityForTicket
        require(_resultTickets.length == _pairAddresses.length, ' tick/pair arr length mismatch :o ');
        // algorithmic logic ...
        //  calc sum of usd value dex prices for all addresses in '_mark.resultOptionTokens' (except _ticket)
        //   -> input _ticket target price = 1 - SUM(all prices except _ticket)
        //   -> if result target price <= 0, then set/return input _ticket target price = $0.01

        // address[] memory tickets = _mark.marketResults.resultOptionTokens;
        address[] memory tickets = _resultTickets;
        uint64 alt_sum = 0;
        for(uint16 i=0; i < tickets.length;) { // MAX_RESULTS is uint16
            if (tickets[i] != _resultTickets[_tickIdx]) {
                address pairAddress = _pairAddresses[i];
                uint256 usdAmountsOut = _estimateLastPriceForTCK(pairAddress); // invokes _normalizeStableAmnt
                alt_sum += _uint64_from_uint256(_normalizeStableAmnt(IERC20x(_resultStables[i]).decimals(), usdAmountsOut, _usd_decs));
            }
            
            unchecked {i++;}
        }

        // NOTE: returns negative if alt_sum is greater than 1
        //  edge case should be handle in caller
        int64 target_price = 1 - int64(alt_sum);
        return target_price > 0 ? uint64(target_price) : _usdMinTargetPrice; // note: min is likely 10000 (ie. $0.010000 w/ _usd_decimals() = 6)
    }
    function genMarketResultReview(address _sender, ICallitLib.MARKET memory _mark, ICallitLib.MARKET_REVIEW[] memory _makerReviews, bool _resultAgree) external pure returns(ICallitLib.MARKET_REVIEW memory) {
        uint64 agreeCnt = 0;
        uint64 disagreeCnt = 0;
        uint64 reviewCnt = _uint64_from_uint256(_makerReviews.length);
        if (reviewCnt > 0) {
            agreeCnt = _makerReviews[reviewCnt-1].agreeCnt;
            disagreeCnt = _makerReviews[reviewCnt-1].disagreeCnt;
        }

        agreeCnt = _resultAgree ? agreeCnt+1 : agreeCnt;
        disagreeCnt = !_resultAgree ? disagreeCnt+1 : disagreeCnt;
        return (ICallitLib.MARKET_REVIEW(_sender, _resultAgree, _mark.maker, _mark.marketNum, _mark.marketHash, agreeCnt, disagreeCnt, reviewCnt));
    }
    function getValidVoteCount(uint64 _tokensHeld_noDecs, uint32 _ratioTokPerVote, uint64 _votesEarned, uint256 _voterLockTime, uint256 _markCreateTime) external pure returns(uint64) {
        // calc organic votes held based on ratio input & add to votes earned input
        uint64 votes_held =  _tokensHeld_noDecs * _ratioTokPerVote;
        _votesEarned += votes_held;

        // NOTE: this function accounts for whole number votes (ie. no decimals)
        // if indeed locked && locked before _mark start time, calc & return active vote count
        if (_voterLockTime > 0 && _voterLockTime <= _markCreateTime) {
            uint64 votes_active = _tokensHeld_noDecs >= _votesEarned ? _votesEarned : _tokensHeld_noDecs;
            return votes_active;
        }
        else
            return 0; // return no valid votes
    }
    function _addressIsMarketMakerOrCaller(address _addr, address _markMaker, address[] memory _resultOptionTokens) external view returns(bool, bool) {
        bool is_maker = _markMaker == _addr; // true = found maker
        bool is_caller = false;
        for (uint16 i = 0; i < _resultOptionTokens.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535
            is_caller = IERC20(_resultOptionTokens[i]).balanceOf(_addr) > 0; // true = found caller
            unchecked {i++;}
        }

        return (is_maker, is_caller);
    }
    function _getWinningVoteIdxForMarket(uint64[] memory _resultTokenVotes) external pure returns(uint16) {
        // travers mark.resultTokenVotes for winning idx
        //  NOTE: default winning index is 0 & ties will settle on lower index
        uint16 idxCurrHigh = 0;
        for (uint16 i = 0; i < _resultTokenVotes.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535
            if (_resultTokenVotes[i] > _resultTokenVotes[idxCurrHigh])
                idxCurrHigh = i;
            unchecked {i++;}
        }
        return idxCurrHigh;
    }
    function _getAmountsForInitLP(uint256 _usdAmntLP, uint256 _resultOptionCnt, uint32 _tokPerUsd) external pure returns(uint64, uint256) {
        require (_usdAmntLP > 0 && _resultOptionCnt > 0 && _tokPerUsd > 0, ' uint == 0 :{} ');
        // return (_uint64_from_uint256(_usdAmntLP / _resultOptionCnt), uint256((_usdAmntLP / _resultOptionCnt) * _tokPerUsd));
            // NOTE: _uint64_from_uint256 checked OK

        uint64 usdAmountLP_ind = _uint64_from_uint256(_usdAmntLP / _resultOptionCnt);
        uint256 tokAmntLP_ind = _normalizeStableAmnt(6, usdAmountLP_ind * _tokPerUsd, 18); // convert from usd decs to ticket decs
        return (usdAmountLP_ind, tokAmntLP_ind);
            // NOTE: _usdAmntLP & _tokPerUsd coming in from DELEGATE.makeNewMarket -> VAULT.createDexLP
            //  _usdAmntLP, will always be w/in uint64 range, formated in VAULT._usd_decimals() -> 6
            //  _tokPerUsd, hence needs to add 10**12 decimals, matching ERC20's standard -> 18 (needed for CallitTicket.sol)
    }
    function _calculateTokensToMint(address _pairAddr, uint256 _usdTargetPrice) external view returns (uint256) {
        // NOTE: chatGPT requirements ...
        //  token0 in _pairAddr is an ERC20 with 18 decimal precision 
        //  token1 in _pairAddr is an ERC20 usd stable token that may be any decimal precision 
        //  _usdTargetPrice is already normalized to 18 decimals
        // Step 1: Get the reserves from the pair contract
        IUniswapV2Pair pair = IUniswapV2Pair(_pairAddr);
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();

        // Step 2: Get the decimal precision of token1 (the USD stable token)
        IERC20x token1 = IERC20x(pair.token1());
        uint8 token1Decimals = token1.decimals();

        // Step 3: Normalize reserve1 to 18 decimals
        uint256 reserve1Normalized = uint256(reserve1) * (10**(18 - token1Decimals));

        // Step 4: Calculate the current price of token0 in terms of token1 (already normalized to 18 decimals)
        uint256 currentPrice = reserve1Normalized * 1e18 / uint256(reserve0);

        // Step 5: Calculate the difference in price and the required amount of token0 to mint
        if (_usdTargetPrice <= currentPrice) {
            return 0; // No need to mint if target price is not higher
        }

        uint256 requiredMint = (reserve1Normalized * 1e18 / _usdTargetPrice) - uint256(reserve0);

        return requiredMint;
    }
    // Option 1: Estimate the price using reserves
    function _estimateLastPriceForTCK(address _pairAddress) private view returns (uint256) {
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(_pairAddress).getReserves();
        
        // Assuming token0 is the ERC20 token and token1 is the paired asset (e.g., ETH or a stablecoin)
        uint256 price = reserve1 * 1e18 / reserve0; // 1e18 for consistent decimals if token1 is ETH or a stablecoin
        return price;
    }
    function _perc_total_supply_owned(address _token, address _account) external view returns (uint64) {
        uint256 accountBalance = IERC20(_token).balanceOf(_account);
        uint256 totalSupply = IERC20(_token).totalSupply();

        // Prevent division by zero by checking if totalSupply is greater than zero
        require(totalSupply > 0, "Total supply must be greater than zero");

        // Calculate the percentage (in basis points, e.g., 1% = 100 basis points)
        uint256 percentage = (accountBalance * 10000) / totalSupply;

        return _uint64_from_uint256(percentage); // Returns the percentage in basis points (e.g., 500 = 5%)
    }
    // function _deductFeePerc(uint64 _net_usdAmnt, uint16 _feePerc, uint64 _usdAmnt) external pure returns(uint64) {
    //     require(_feePerc <= 10000, ' invalid fee perc :p '); // 10000 = 100.00%
    //     return _net_usdAmnt - _perc_of_uint64(_feePerc, _usdAmnt);
    // }
    function _deductFeePerc(uint64 _net_usdAmnt, uint16 _feePerc, uint64 _usdAmnt) external pure returns(uint64) {
        require(_feePerc <= 10000, ' invalid fee perc :p '); // 10000 = 100.00%
        uint64 usd_perc = (_usdAmnt * uint64(_feePerc * 100)) / 1000000; // chatGPT equation
        require(_net_usdAmnt >= usd_perc, ' bad perc calc :-/ ');
        return _net_usdAmnt - usd_perc;
    }
    function _isAddressInArray(address _addr, address[] memory _addrArr) external pure returns(bool) {
        for (uint8 i = 0; i < _addrArr.length;){ // max array size = 255 (uin8 loop)
            if (_addrArr[i] == _addr)
                return true;
            unchecked {i++;}
        }
        return false;
    }
    function _genTokenNameSymbol(address _maker, uint256 _markNum, uint16 _resultNum, string memory _nameSeed, string memory _symbSeed) external pure returns(string memory, string memory) { 
        string memory str_maker = Strings.toHexString(_maker);
        string memory last4 = _getLastNChars(str_maker, 4);
        string memory markNum = Strings.toString(_markNum); 
        string memory resultNum = Strings.toString(_resultNum);
        string memory tokenSymbol = string(abi.encodePacked(_nameSeed, last4, markNum, resultNum));
        string memory tokenName = string(abi.encodePacked(_symbSeed, " ", last4, ".", markNum, ".", resultNum));
        return (tokenName, tokenSymbol);
    }
    function _getLastNChars(string memory str, uint256 n) private pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        require(n <= strBytes.length, "N exceeds string length");

        bytes memory result = new bytes(n);
        uint start = strBytes.length - n;
        for (uint i = 0; i < n; i++) {
            result[i] = strBytes[start + i];
        }

        return string(result);
    }
    function _validNonWhiteSpaceString(string calldata _s) external pure returns(bool) {
        for (uint8 i=0; i < bytes(_s).length;) {
            if (bytes(_s)[i] != 0x20) {
                // Found a non-space character, return true
                return true; 
            }
            unchecked {
                i++;
            }
        }

        // found string with all whitespaces as chars
        return false;
    }
    // function genHashOfAddies(address[] calldata addies) external pure returns (address) {
    //     // Initialize a bytes array for encoding
    //     bytes memory data;

    //     // Loop through each address in the array and append it to the data
    //     for (uint i = 0; i < addies.length; i++) {
    //         data = abi.encodePacked(data, addies[i]);
    //     }

    //     // // Append the UID string to the encoded data
    //     // data = abi.encodePacked(data, uid);

    //     // Hash the concatenated data
    //     bytes32 hash = keccak256(data);

    //     // Cast the resulting hash to an address, similar to before
    //     address hashAddy = address(uint160(uint256(hash))); // note: triple cast correct & required
    //     return hashAddy;
    // }
    function _generateAddressHash(address host, string memory uid) external pure returns (address) {
        // Concatenate the address and the string, and then hash the result
        bytes32 hash = keccak256(abi.encodePacked(host, uid));

        // NOTE: ... required & not a bug
        //  keccak256 returns a bytes32 hash, which is a 256-bit value (uint256)
        //  Ethereum addresses are 160 bits long (20 bytes), 
        //   when converting a bytes32 hash to address, truncating required to fit into 160 bits
        address generatedAddress = address(uint160(uint256(hash)));
        return generatedAddress;
    }
    // function _perc_of_uint64(uint32 _perc, uint64 _num) public pure returns (uint64) {
    //     require(_perc <= 10000, 'err: invalid percent');
    //     uint64 perc_scaled = uint64(_perc) * 100; // safe scaling before multiplication
    //     require(perc_scaled <= type(uint64).max / _num, 'err: overflow risk');
    //     return (_num * perc_scaled) / 1000000;
    // }
    // function _perc_of_uint64(uint32 _perc, uint64 _num) public pure returns (uint64) {
    function _perc_of_uint64(uint16 _perc, uint64 _num) public pure returns (uint64) {
        require(_perc <= 10000, 'err: invalid percent');
        // return _perc_of_uint64_unchecked(_perc, _num);
        return (_num * uint64(_perc * 100)) / 1000000; // chatGPT equation
    }
    function _perc_of_uint64_unchecked(uint32 _perc, uint64 _num) external pure returns (uint64) {
        // require(_perc <= 10000, 'err: invalid percent');
        // uint32 aux_perc = _perc * 100; // Multiply by 100 to accommodate decimals
        // uint64 result = (_num * uint64(aux_perc)) / 1000000; // chatGPT equation
        // return result; // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)

        // NOTE: more efficient with no local vars allocated
        return (_num * uint64(uint32(_perc) * 100)) / 1000000; // chatGPT equation
    }
    function _uint64_from_uint256(uint256 value) public pure returns (uint64) {
        require(value <= type(uint64).max, "Value exceeds uint64 range");
        uint64 convertedValue = uint64(value);
        return convertedValue;
    }
    function _normalizeStableAmnt(uint8 _fromDecimals, uint256 _usdAmnt, uint8 _toDecimals) public pure returns (uint256) {
        require(_fromDecimals > 0 && _toDecimals > 0, 'err: invalid _from|toDecimals');
        if (_usdAmnt == 0) return _usdAmnt; // fix to allow 0 _usdAmnt (ie. no need to normalize)
        if (_fromDecimals == _toDecimals) {
            return _usdAmnt;
        } else {
            if (_fromDecimals > _toDecimals) { // _fromDecimals has more 0's
                uint256 scalingFactor = 10 ** (_fromDecimals - _toDecimals); // get the diff
                return _usdAmnt / scalingFactor; // decrease # of 0's in _usdAmnt
            }
            else { // _fromDecimals has less 0's
                uint256 scalingFactor = 10 ** (_toDecimals - _fromDecimals); // get the diff
                return _usdAmnt * scalingFactor; // increase # of 0's in _usdAmnt
            }
        }
    }
    function _addAddressToArraySafe(address _addr, address[] memory _arr, bool _safe) external pure returns (address[] memory) {
        // NOTE: no require checks needed
        return _addAddressToArraySafe_p(_addr, _arr, _safe);
    }
    function _remAddressFromArray(address _addr, address[] memory _arr) external pure returns (address[] memory) {
        // NOTE: no require checks needed
        return _remAddressFromArray_p(_addr, _arr);
    }

    /* -------------------------------------------------------- */
    /* PRIVATE
    /* -------------------------------------------------------- */
    function _getLast4Chars(address _addr) private pure returns (string memory) {
        // Convert the last 2 bytes (4 characters) of the address to a string
        bytes memory addrBytes = abi.encodePacked(_addr);
        bytes memory last4 = new bytes(4);

        last4[0] = addrBytes[18];
        last4[1] = addrBytes[19];
        last4[2] = addrBytes[20];
        last4[3] = addrBytes[21];

        return string(last4);
    }
    function _addAddressToArraySafe_p(address _addr, address[] memory _arr, bool _safe) private pure returns (address[] memory) {
        if (_addr == address(0)) { return _arr; }

        // safe = remove first (no duplicates)
        if (_safe) { _arr = _remAddressFromArray_p(_addr, _arr); }

        // perform add to memory array type w/ static size
        address[] memory _ret = new address[](_arr.length+1);
        for (uint i=0; i < _arr.length;) { _ret[i] = _arr[i]; unchecked {i++;}}
        _ret[_ret.length-1] = _addr;
        return _ret;
    }
    function _remAddressFromArray_p(address _addr, address[] memory _arr) private pure returns (address[] memory) {
        if (_addr == address(0) || _arr.length == 0) { return _arr; }
        
        // NOTE: remove algorithm does NOT maintain order & only removes first occurance
        for (uint i = 0; i < _arr.length;) {
            if (_addr == _arr[i]) {
                _arr[i] = _arr[_arr.length - 1];
                assembly { // reduce memory _arr length by 1 (simulate pop)
                    mstore(_arr, sub(mload(_arr), 1))
                }
                return _arr;
            }

            unchecked {i++;}
        }
        return _arr;
    }
}