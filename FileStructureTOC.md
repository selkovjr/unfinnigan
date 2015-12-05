The "raw" data files generated by various Thermo instruments in various modes of operation can contain different kinds of objects laid out in a number of different configurations. Some of these layouts are specific to the instrument and the scan mode used, but there are some motifs that occur in all files. For example, all files originating from the Thermo mass spectrometers start with the same header and carry the Finnigan signature. The same is true of various embedded subfiles found in these files -- that is why I have developed the habit of referring to them as Finnigan files. I do not know what they are called officially.

The purpose if this document is to present my (limited) observations of this variety and to give you clues for how you can figure out the data you are working with, if it differs from what I see.

**[Currently supported versions](SupportedVersions.md)**

**[File roadmap (typical file layout and reading strategies)](FileLayoutOverview.md)**

**Data structures**

> (approximately in the order of their occurrence in the file, with **streams** highlighted in bold)

  * [FileHeader](FileHeader.md)
    * [AuditTag](AuditTag.md)

  * [SeqRow](SeqRow.md) (_varies with file version_)
    * [InjectionData](InjectionData.md)

  * [ASInfo](ASInfo.md)
    * [ASInfoPreamble](ASInfoPreamble.md)

  * [RawFileInfo](RawFileInfo.md)
    * [RawFileInfoPreamble](RawFileInfoPreamble.md)

  * [MethodFile](MethodFile.md) (an embedded Microsoft OLE2 container)
    * [Method file structure](MethodFileStructure.md)
    * [Instrument method data](InstrumentMethodData.md) (unexplored area)

  * **Scan data**
    * [ScanDataPacket](ScanDataPacket.md)
      * [PacketHeader](PacketHeader.md)
      * [Profile](Profile.md)
      * [PeakList](PeakList.md)
      * [PeakDescriptors](PeakDescriptors.md)
      * [UnknownStream](UnknownStream.md)
      * [UnknownTriplets](UnknownTriplets.md)

  * [RunHeader](RunHeader.md)
    * [SampleInfo](SampleInfo.md)

  * [InstID](InstID.md)

  * **[Instrument log](InstrumentLog.md)**
    * [InstrumentLogRecord](InstrumentLogRecord.md)

  * **[Error log](ErrorLog.md)**
    * [Error](Error.md)

  * [Scan event hierarchy](ScanEventHierarchy.md)
    * [ScanEventTemplate](ScanEventTemplate.md)

  * **[Scan parameters stream](ScanParametersStream.md)**
    * [ScanParameters](ScanParameters.md) (_out of order, located near the end of the file_)

  * [Tune file](TuneFile.md)

  * **[Scan index stream](ScanIndexStream.md)**
    * [ScanIndexEntry](ScanIndexEntry.md)

  * **[Scan event stream](ScanEventStream.md)** (_"trailer"_)
    * [ScanEvent](ScanEvent.md)
      * [ScanEventPreamble](ScanEventPreamble.md)
      * [FractionCollector](FractionCollector.md)
      * [Reaction](Reaction.md)

  * **[Unknown stream at the end](UnknownStream.md)** -- _LC data?_

**Common data structures and idioms**

  * [GenericRecord](GenericRecord.md)
  * [GenericDataHeader](GenericDataHeader.md)
    * [GenericDataDescriptor](GenericDataDescriptor.md)

**Instrument-specific data structures**

  * Finnigan MAT LCQ
    * [PeakData](PeakData.md)
    * [SeqRow](SeqRow#Finnigan_MAT_LCQ.md)

  * LTQ-FT
    * [SeqRow](SeqRow#LTQ-FT.md)
    * [DetectorSignal](DetectorSignal#LTQ-FT_Spectra.md)

  * LTQ Orbitrap
    * [SeqRow](SeqRow#LTQ-Orbitrap.md)
    * [DetectorSignal](DetectorSignal#LTQ-Orbitrap_Spectra.md)

> Examples

  * [GenericRecord](GenericRecordExample.md)