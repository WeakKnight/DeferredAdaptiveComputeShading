uint _WaveActiveMask(bool condition)
{
    __target_switch
    {
        case metal:
            __intrinsic_asm "((uint32_t)((simd_vote::vote_t)simd_ballot($0)))";
        default:
            return WaveActiveBallot(condition).x;
    }
}

uint _WavePrefixSum(uint val)
{
    __target_switch
    {
    case metal:
        __intrinsic_asm "simd_prefix_exclusive_sum($0)";
    default:
        return WavePrefixSum((val>0));
    }
}

uint _WaveActiveCountBits(bool condition)
{
    __target_switch
    {
    case metal:
        return countbits(_WaveActiveMask(condition));
    default:
        return WaveActiveCountBits(condition);
    }
}

uint _WavePrefixCountBits(bool condition)
{
    __target_switch
    {
    case metal:
        return _WavePrefixSum(condition? 1u: 0u);
    default:
        return WavePrefixCountBits(condition);
    }
}

void WavePartition2(bool isTrue, out uint newLaneIndex, out uint trueCount)
{
    trueCount = _WaveActiveCountBits(isTrue);
    uint trueBefore = _WavePrefixCountBits(isTrue);
    uint lane = WaveGetLaneIndex();
    uint falseBefore = lane - trueBefore;
    newLaneIndex = isTrue ? trueBefore : (trueCount + falseBefore);
}