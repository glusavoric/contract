pragma solidity ^0.4.24;

import "./UTXORedeemableToken.sol";
import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract StakeableToken is UTXORedeemableToken {
  using SafeMath for uint256;

  /**
   * @dev Calculates weareallsatoshi bonus for a given stake
   * @param _amount param of stake to calculate bonuses for
   * @param _stakeTime param of stake to calculate bonuses for
   * @param _unlockTime param of stake to calculate bonuses for
   * @return bonus amount
   */
  function calculateWeAreAllSatoshiRewards(
    uint256 _amount,
    uint256 _stakeTime,
    uint256 _unlockTime
  ) private view returns(uint256) {
    uint256 _bonus = 0;

    /* Calculate what week stake was opened */
    uint256 _startWeekCandidate = timestampToWeeks(_stakeTime);

    /* Bonuses are not deducted nor given before end of first week of contract launching */
    uint256 _startWeek = _startWeekCandidate == 0 ? 1 : _startWeekCandidate;

    /* Calculate last week of stake */
    uint256 _endWeek = timestampToWeeks(_unlockTime);

    uint256 _rewardableEndWeek = _endWeek > 50 ? 50 : _endWeek;

    /* Award 2% of unclaimed coins at end of every week - We intentionally overshoot to compensate for reduction from late claim scaling */
    for (uint256 _i = _startWeek; _i < _rewardableEndWeek; _i++) {
      /* Calculate what proportion of unclaimed coins stake is entitled to, and calculate 2% of it (div 50) */
      uint256 _satoshiRewardWeek = weeklyData[_i].unclaimedCoins.mul(_amount).div(50);

      /* Add to tally */
      _bonus = _bonus.add(_satoshiRewardWeek);
    }

    return _bonus;
  }
  
  /**
   * @dev PUBLIC FACING: Calculates total bonuses for a given stake
   * @param _amount param of stake to calculate bonuses for
   * @param _stakeTime param of stake to calculate bonuses for
   * @param _unlockTime param of stake to calculate bonuses for
   * @return bonus amount
   */
  function calculateBonuses(
    uint256 _amount,
    uint256 _stakeTime,
    uint256 _unlockTime
  ) public view returns (uint256) {
    uint256 _bonus = 0;
    if (isClaimsPeriod()) {
      _bonus = _bonus.add(calculateWeAreAllSatoshiRewards(
        _amount,
        _stakeTime,
        _unlockTime
      ));
    }
    return _bonus;
  }

  /**
   * @dev PUBLIC FACING: Calculates stake payouts for a given stake
   * @param _amount param of stake to calculate bonuses for
   * @param _stakeShares param of stake to calculate bonuses for
   * @param _stakeTime param of stake to calculate bonuses for
   * @param _unlockTime param of stake to calculate bonuses for
   * @return payout amount
   */
  function calculatePayout(
    uint256 _amount,
    uint256 _stakeShares,
    uint256 _stakeTime,
    uint256 _unlockTime
  ) public view returns (uint256) {
    uint256 _payout = 0;

    /* Calculate what period stake was opened */
    uint256 _startPeriod = timestampToPeriods(_stakeTime);

    /* Calculate what period stake was closed */
    uint256 _endPeriod = timestampToPeriods(_unlockTime);

    /* Loop though each period and tally payout */
    for (uint256 _i = _startPeriod; _i < _endPeriod; _i++) {
      /* Calculate payout from period */
      uint256 _periodPayout = periodData[_i].payoutRoundAmount.mul(_stakeShares).div(periodData[_i].totalStaked);

      /* Add to tally */
      _payout = _payout.add(_periodPayout);
    }

    return _payout;
  }

  /**
   * @dev PUBLIC FACING: Open a stake
   * @param _satoshis Amount of satoshi to stake
   * @param _periods Number of 10 day periods to stake
   */
  function startStake(
    uint256 _satoshis,
    uint256 _periods
  ) external {
    /* Calculate Unlock time */
    uint256 _unlockTime = block.timestamp.add(_periods.mul(oneInterestPeriod));

    /* Make sure staker has enough funds */
    require(balanceOf(msg.sender) >= _satoshis);
    
    /* ensure that unlock time is not more than approx 10 years */
    require(_unlockTime <= block.timestamp.add(maxStakingTime));

    /* ensure that unlock time is more than 10 days */
    require(_unlockTime >= block.timestamp.add(oneInterestPeriod));

    /* Check if log data needs to be updated */
    storeWeeklyData();
    storePeriodData();

    /* Calculate stake shares */
    uint256 _sharesModifier = _periods.mul(200).div(360);
    uint256 _stakeShares = _satoshis.add(_satoshis.mul(_sharesModifier).div(100));

    /* Create Stake */
    staked[msg.sender].push(
      StakeStruct(
        _satoshis,
        _stakeShares,
        block.timestamp,
        _unlockTime
      )
    );

    /* Add staked coins to global stake counter */
    totalStakedCoins = totalStakedCoins.add(_satoshis);

    /* Add staked shares to global stake counter */
    totalStakeShares = totalStakeShares.add(_stakeShares);

    /* Move coins to staking address to store */
    _transfer(msg.sender, stakingAddress, _satoshis);
  }

  /**
   * @dev PUBLIC FACING: Closes a stake
   * @param _stakeIndex Index of stake to close
   */
  function endStake(
    uint256 _stakeIndex
  ) external {

  }
}
