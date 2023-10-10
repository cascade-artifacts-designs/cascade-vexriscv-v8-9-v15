package vexriscv.demo


import spinal.core._
import spinal.lib._
import spinal.lib.bus.avalon.AvalonMM
import spinal.lib.com.jtag.{Jtag, JtagTapInstructionCtrl}
import spinal.lib.eda.altera.{InterruptReceiverTag, QSysify, ResetEmitterTag}
import vexriscv.ip.{DataCacheConfig, InstructionCacheConfig}
import vexriscv.plugin._
import vexriscv.{VexRiscv, VexRiscvConfig, plugin}
import vexriscv.ip.fpu.{FpuCore, FpuParameter}

/**
 * Created by spinalvm on 14.07.17.
 */
//class VexRiscvAvalon(debugClockDomain : ClockDomain) extends Component{
//
//}

//make clean run DBUS=SIMPLE_AHBLITE3 IBUS=SIMPLE_AHBLITE3 MMU=no CSR=no DEBUG_PLUGIN=STD

object VexRiscvAhbLite3cascade{
  def main(args: Array[String]) {
    import spinal.core.internals._
    import scala.util.Random
    class PhaseRandomizedMem() extends PhaseNetlist {
      override def impl(pc: PhaseContext): Unit = {
        pc.walkDeclarations{
          case mem : Mem[_] if mem.initialContent == null => {
            mem.initBigInt(Array.fill(mem.wordCount)(BigInt.apply(mem.width, Random)))
          }
          case _ =>
        }
      }
    }

    val report = SpinalConfig(mode = if(args.contains("--vhdl")) VHDL else Verilog, inlineRom = true).generate{

      //CPU configuration
      val cpuConfig = VexRiscvConfig(
        plugins = List(
          // new IBusSimplePlugin(
          //   resetVector = 0x80000000l,
          //   cmdForkOnSecondStage = false,
          //   cmdForkPersistence = true,
          //   prediction = DYNAMIC_TARGET,
          //   catchAccessFault = true,
          //   compressedGen = true
          // ),
          // new DBusSimplePlugin(
          //   catchAddressMisaligned = true,
          //   catchAccessFault = true
          // ),
          new IBusCachedPlugin(
            resetVector = 0x80000000l,
            compressedGen = false, // TODO
            prediction = STATIC, // TODO
            historyRamSizeLog2 = 4,
            injectorStage = false,
            config = InstructionCacheConfig(
              cacheSize = 4096*1,
              bytePerLine = 8,
              wayCount = 2,
              addressWidth = 32,
              cpuDataWidth = 32,
              memDataWidth = 64,
              catchIllegalAccess = true,
              catchAccessFault = true,
              asyncTagMemory = false,
              twoCycleRam = false, // TODO Try to change to add variability, given assertion assert(twoCycleCache | !twoCycleRAM)
              twoCycleCache = false // TODO Try to change to add variability, given assertion assert(twoCycleCache | !twoCycleRAM)
            ),
            memoryTranslatorPortConfig = MmuPortConfig(
              portTlbSize = 4
            )
          ),
          new DBusCachedPlugin(
            dBusCmdMasterPipe = true,
            dBusCmdSlavePipe = true,
            dBusRspSlavePipe = true,
            config = new DataCacheConfig(
              cacheSize         = 4096*1,
              bytePerLine       = 8,
              wayCount          = 2,
              addressWidth      = 32,
              cpuDataWidth      = 64,
              memDataWidth      = 64,
              catchAccessError  = true,
              catchIllegal      = true,
              catchUnaligned    = true,
              withExclusive = false, // = withsmp
              withInvalidate = false, // = withsmp
              withLrSc = false,
              withAmo = false,
              withWriteAggregation = false
            ),
            memoryTranslatorPortConfig = MmuPortConfig(
              portTlbSize = 4
            )
          ),
          new MmuPlugin(
            virtualRange = _(31 downto 28) === 0xC,
            ioRange      = _(31 downto 28) === 0xF
          ),
          new FpuPlugin(
            externalFpu = false,
            simHalt = false,
            p = FpuParameter(withDouble = true)
          ),
          new DecoderSimplePlugin(
            catchIllegalInstruction = true
          ),
          new RegFilePlugin(
            regFileReadyKind = plugin.SYNC,
            zeroBoot = false
          ),
          new IntAluPlugin,
          new SrcPlugin(
            separatedAddSub = false,
            executeInsertion = true
          ),
          new FullBarrelShifterPlugin,
          new MulPlugin,
          new DivPlugin,
          new HazardSimplePlugin(
            bypassExecute           = true,
            bypassMemory            = true,
            bypassWriteBack         = true,
            bypassWriteBackBuffer   = true,
            pessimisticUseSrc       = false,
            pessimisticWriteRegFile = false,
            pessimisticAddressMatch = false
          ),
          new BranchPlugin(
            earlyBranch = false,
            catchAddressMisaligned = true
          ),
          new CsrPlugin(
            config = CsrPluginConfig(
              catchIllegalAccess  = true,
              mvendorid           = 0,
              marchid             = 0,
              mimpid              = 0,
              mhartid             = 0,
              misaExtensionsInit  = 0,
              misaAccess          = CsrAccess.READ_ONLY,
              mtvecAccess         = CsrAccess.READ_WRITE,   //Could have been WRITE_ONLY :(
              mtvecInit           = null,
              mepcAccess          = CsrAccess.READ_WRITE,
              mscratchGen         = true,
              mcauseAccess        = CsrAccess.READ_WRITE,
              mbadaddrAccess      = CsrAccess.READ_WRITE,
              mcycleAccess        = CsrAccess.READ_WRITE,
              minstretAccess      = CsrAccess.READ_WRITE,
              ucycleAccess        = CsrAccess.READ_ONLY,
              wfiGenAsWait        = true,
              ecallGen            = true,
              xtvecModeGen        = false,
              noCsrAlu            = false,
              wfiGenAsNop         = false,
              ebreakGen           = true,
              userGen             = true,
              supervisorGen       = true,
              sscratchGen         = true,
              stvecAccess         = CsrAccess.READ_WRITE,
              sepcAccess          = CsrAccess.READ_WRITE,
              scauseAccess        = CsrAccess.READ_WRITE,
              sbadaddrAccess      = CsrAccess.READ_WRITE,
              scycleAccess        = CsrAccess.READ_ONLY,
              sinstretAccess      = CsrAccess.READ_ONLY,
              uinstretAccess      = CsrAccess.READ_ONLY,
              satpAccess          = CsrAccess.READ_WRITE,
              medelegAccess       = CsrAccess.READ_WRITE,  //Could have been WRITE_ONLY :(
              midelegAccess       = CsrAccess.READ_WRITE,  //Could have been WRITE_ONLY :(
              pipelineCsrRead     = false,
              deterministicInteruptionEntry  = false
            )
          ),
          new YamlPlugin("cpu0.yaml")
        )
      )

      val cpu = new VexRiscv(cpuConfig)
      cpu
    }
  }
}

