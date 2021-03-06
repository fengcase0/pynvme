#
#  BSD LICENSE
#
#  Copyright (c) Crane Che <cranechu@gmail.com>
#  All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions
#  are met:
#
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in
#      the documentation and/or other materials provided with the
#      distribution.
#    * Neither the name of Intel Corporation nor the names of its
#      contributors may be used to endorse or promote products derived
#      from this software without specific prior written permission.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
#  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
#  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
#  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
#  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

#!/usr/bin/python3
# -*- coding: utf-8 -*-

#cython: binding=True
#cython: language_level=3
##//cython: linetrace=True
##//distutils: define_macros=CYTHON_TRACE=1


"""pynvme, testing NVMe targets in Python

https://github.com/cranechu/pynvme

Pynvme Driver is a python extension module. Users can operate NVMe SSD intuitively by Python scripts. It is designed for NVMe SSD testing with performance considered. With third-party tools, e.g. pycharm and pytest, Pynvme is a convinent and professional NVMe device test solution. It can test multiple NVMe DUT devices, operate most of the NVMe commands, support callback functions, and manage reset/power of NVMe devices. User needs root privilage to use pynvme.

Pynvme provides several classes to access and test NVMe devices:
1. Subsystem: controls the power and reset of NVMe subsystem
2. Pcie: accesses PCIe device's config space
3. Controller: accesses NVMe registers and operates admin commands
4. Namespace: abstracts NVMe namespace and operates NVM commands
5. Qpair: manages NVMe IO SQ/CQ. Admin SQ/CQ are managed by Controller
6. Buffer: allocates and manipulates the data buffer on host memory
7. IOWorker: reads and/or writes NVMe Namespace in seperated processors
Please use "help" to find more details of these classes.

Pynvme works on Linux, and uses SPDK as the NVMe driver. DPDK and SPDK are statically linked in the module's .so object file, so users do not need to setup SPDK develop environment. The host Linux OS image is installed in a SATA drive, because the kernel's NVMe drive will be unloaded by Pynvme during the test. Pynvme does write data to your NVMe devices, so it could corrupt your data in the device. Users have to provide correct BDF (Bus:Device.Function) address to initialize the controller of the DUT device.


Tutorial
========

Pynvme is easy to use, from simple operations to deliberated designed test scripts. User can leverage well developed tools and knowledges in Python community. Here are some Pynvme script examples.

Fetch the controller's identify data. Example:
```python
    >>> import nvme as d
    >>> nvme0 = d.Controller(b"01:00.0")  # initialize NVMe controller with its PCIe BDF address
    >>> id_buf = d.Buffer(4096)  # allocate the buffer
    >>> nvme0.identify(id_buf, nsid=0xffffffff, cns=1)  # read namespace identify data into buffer
    >>> nvme0.waitdone()  # nvme commands are executed asynchorously, so we have to
    >>> id_buf.dump()   # print the whole buffer
```

Yet another hello world example of SPDK nvme driver. Example:
```python
    >>> import nvme as d
    >>> data_buf = d.Buffer(512)
    >>> data_buf[100:] = b'hello world'
    >>> nvme0 = d.Controller(b"01:00.0")
    >>> nvme0n1 = d.Namespace(nvme0, 1)
    >>> qpair = d.Qpair(nvme0, 16)  # create IO SQ/CQ pair, with 16 queue-depth
    >>> def write_cb(cdw0, status):  # command callback function
    >>>     nvme0n1.read(qpair, data_buf, 0, 1).waitdone()
    >>> nvme0n1.write(qpair, data_buf, 0, 1, cb=write_cb).waitdone()
    >>> qpair.cmdlog()  # print recently issued commands
    >>> assert data_buf[100:] = b'hello world'
```

Performance test, while monitoring the device temperature. Example:
```python
    >>> import nvme as d
    >>> nvme0 = d.Controller(b"01:00.0")
    >>> nvme0n1 = d.Namespace(nvme0, 1)
    >>> with nvme0n1.ioworker(lba_start = 0, io_size = 256, lba_align = 8,
                              lba_random = False,
                              region_start = 0, region_end = 100000,
                              read_percentage = 0,
                              iops = 0, io_count = 1000000, time = 0,
                              qprio = 0, qdepth = 16), \\
             nvme0n1.ioworker(lba_start = 0, io_size = 7, lba_align = 11,
                              lba_random = False,
                              region_start = 0, region_end = 1000,
                              read_percentage = 0,
                              iops = 0, io_count = 100, time = 1000,
                              qprio = 0, qdepth = 64), \\
             nvme0n1.ioworker(lba_start = 0, io_size = 8, lba_align = 64,
                              lba_random = False,
                              region_start = 10000, region_end = 1000000,
                              read_percentage = 67,
                              iops = 10000, io_count = 1000000, time = 1000,
                              qprio = 0, qdepth = 16), \\
             nvme0n1.ioworker(lba_start = 0, io_size = 8, lba_align = 8,
                              lba_random = True,
                              region_start = 0, region_end = 0xffffffffffffffff,
                              read_percentage = 0,
                              iops = 10, io_count = 100, time = 0,
                              qprio = 0, qdepth = 16):
    >>>     import time
    >>>     import logging
    >>>     import pytemperature
    >>>     # monitor device temperature on high loading operations
    >>>     logpage_buf = d.Buffer(512)
    >>>     nvme0.getlogpage(2, logpage_buf, 512).waitdone()
    >>>     logging.info("current temperature: %d" % pytemperature.k2c(logpage_buf[50]&0xffff))
    >>>     time.sleep(5)
```


Install
=======

Pynvme is installed by compiling source code. 

System Requirement
------------------

1. Intel CPU with SSE4.2 instruction set
2. Linux, e.g. Fedora latest
2. 8GB DRAM recommended, or more if the DUT capacity is larger
3. deep mode is supported in /sys/power/mem_sleep
3. Tested with Fedora 29 and Python 3.7
4. pytest is used as the test framework
5. security functions (e.g. TCG, pyrite) are not enabled

Source Code
-----------
```shell
git clone https://github.com/cranechu/pynvme
git submodule update --init --recursive
```

Prerequisites
-------------
```shell
./spdk/scripts/pkgdep.sh
sudo python3 -m pip install -r requirements.txt
```

Build
-----
```shell
cd spdk; ./configure --enable-debug; make; cd ..
make clean; make
```
Now, you can find the generated binary file like: nvme.cpython-37m-x86_64-linux-gnu.so 

Test
----
- Setup SPDK runtime environment and start python3 with root privilege.
```shell
make setup
sudo python3
```
- import pynvme module in python3.
```python
import nvme
```
- You can also try tests in pytest.
```shell
make test
```


Features
========

Pynvme writes and reads data in buffer to NVMe device LBA space. In order to verify the data integrity, it injects LBA address and version information into the write data buffer, and check with them after read completion. Furthermore, Pynvme computes and verifies CRC32 of each LBA on the fly. Both data buffer and LBA CRC32 are stored in host memory, so ECC memory are recommended if you are considering serious tests.

Buffer should be allocated for data commands, and held till that command is completed because the buffer is being used by NVMe device. Users need to pay more attention on the life scope of the buffer in Python test scripts.

NVMe commands are all asychronous. Test scripts can sync thourgh waitdone() method to make sure the command is completed. The method waitdone() polls command Completion Queues. When the optional callback function is provided in a command in Python scripts, the callback funciton is called when that command is completed. Callback functions are eventually called by waitdone(), and so do not call waitdone in callback function to avoid re-entry of waitdone functions, which requires a lock inside.

Pynvme traces recent thousands of commands in the cmdlog, as well as the completion entries. User can list cmdlog to find the commands issued in different command queues, and their timestamps.

The cost is high and unconvinent to send each read and write command in Python scripts. Pynvme provides the low-cost IOWorker to send IOs in different processores. IOWorker takes full use of multi-core to not only send read/write IO in high speed, but also verify the correctness of data on the fly. User can get IOWorker's test statistics through its close() method. Here is an example of reading 4K data randomly with the IOWorker.

Example:
```python
    >>> r = nvme0n1.ioworker(io_size = 8, lba_align = 8,
                             lba_random = True, qdepth = 16,
                             read_percentage = 100, time = 10).start().close()
    >>> print(r.io_count_read)
    >>> print(r.mseconds)
    >>> print("IOPS: %dK/s\\n", r.io_count_read/r.mseconds)
```

The controller is not responsible for checking the LBA of a Read or Write command to ensure any type of ordering between commands (NVMe spec 1.3c, 6.3). It means conflicted read write operations on NVMe devices cannot predict the final data result, and thus hard to verify data correctness. For test scripts, one mitigation solution is separating read and write operations to differnt IOWorkers and different LBA regions, so it can be avoid to read and write same LBA at simultanously. For those read and write operations on same LBA region, scripts have to complete one before submitting the other.

Qpair instance is created based on Controller instance. So, user creates qpair after the controller. In the other side, user should free qpair before the controller. But without explict code, Python may not do the job in right order. One of the mitigation solution is pytest fixture scope. User can define Controller fixture as session scope and Qpair as function. In the situation, qpair is always deleted before the controller.


Restrictions
------------

Pynvme is focused on mainstream client NVMe SSD, following NVMe spec v1.3c. Some features are NOT supported for now. We will continue to develop the features listed below to support more tests and devices in future. New requests and contributions are warmly welcomed.
1. Weighted Round Robin arbitration
2. SGL
3. multiple namespace management
4. Directive operations
5. sudden power cycle: shutdown while writing data
6. metadata and protect information
7. virtualization management
8. security send/receive and RPMB
9. boot partition
10. Management Interface
12. Open-channel SSD
13. Vendor Specific commands
14. platform compatibility
11. NVMe over Fabrics
"""

# python package
import os
import sys
import time
import atexit
import signal
import struct
import logging
import warnings
import statistics
import subprocess
import multiprocessing

# c library
import cython
from libc.string cimport strncpy, memset, strlen
from libc.stdio cimport printf
from cpython.mem cimport PyMem_Malloc, PyMem_Free
from cpython.exc cimport PyErr_CheckSignals

# c driver
cimport cdriver as d


# module informatoin
__author__ = "Crane Chu"
__version__ = "0.1.10"


# nvme command timeout, it's a warning
# driver times out earlier than driver wrap
_cTIMEOUT = 5
cdef void timeout_driver_cb(void* cb_arg, d.ctrlr* ctrlr,
                            d.qpair * qpair, unsigned short cid):
    error_string = "driver timeout: %d sec, qpair: %d, cid: %d" % \
        (_cTIMEOUT, d.qpair_get_id(qpair), cid)
    warnings.warn(error_string)


# timeout signal in wrap layer, it's an assert fail
# driver wrap needs longer timeout, some commands need more time, like format
_cTIMEOUT_wrap = 60
def _timeout_signal_handler(signum, frame):
    error_string = "script timeout: %d sec" % _cTIMEOUT_wrap
    _reentry_flag_init()
    raise TimeoutError(error_string)


# prevent waitdone reentry
def _reentry_flag_init():
    global _reentry_flag
    _reentry_flag = False


# for abrupt exit
def _interrupt_handler(signal, frame):
    logging.debug("terminated.")
    sys.exit(0)


# handle cpl in callback from c
cdef struct _cpl:
    # a revised completion structure returned to user,
    # cdw2 is changed to latency of the command, in micro-seconds
    unsigned int cdw0
    unsigned int rsvd1
    unsigned int latency
    unsigned short cid
    unsigned short status1  #this word actully inculdes some other bites

cdef void cmd_cb(void* f, const d.cpl* cpl):
    arg = <_cpl*>cpl  # no qa
    status1 = arg.status1
    func = <object>f   # no qa

    if func is not None:
        # call script callback function to check cpl
        try:
            func(arg.cdw0, status1)
        except AssertionError as e:
            warnings.warn("ASSERT: "+str(e))
    elif d.nvme_cpl_is_error(cpl):
        # script not check, so driver check cpl
        sc = (status1>>1) & 0xff
        sct = (status1>>9) & 0x7
        warnings.warn("ERROR status: %02x/%02x" % (sct, sc))

cdef void aer_cmd_cb(void* f, const d.cpl* cpl):
    warnings.warn("AER notification is triggered")
    cmd_cb(f, cpl)


cdef class Buffer(object):
    """Buffer class allocated in DPDK memzone,so can be used by DMA. Data in buffer is clear to 0 in initialization.

    Args:
        size (int): the size (in bytes) of the buffer
                    default: 4096
        name (str): the name of the buffer
                    default: 'buffer'

    Examples:
```python
        >>> b = Buffer(1024, 'example')
        >>> b[0] = 0x5a
        >>> b[1:3] = [1, 2]
        >>> b[4:] = [10, 11, 12, 13]
        >>> b.dump(16)
        example
        00000000  5a 01 02 00 0a 0b 0c 0d  00 00 00 00 00 00 00 00   Z...............
        >>> b[:8:2]
        b'Z\\x02\\n\\x0c'
        >>> b.data(2) == 2
        True
        >>> b[2] == 2
        True
        >>> b.data(2, 0) == 0x02015a
        True
        >>> len(b)
        1024
        >>> b
        <buffer name: example>
        >>> b[8:] = b'xyc'
        example
        00000000  5a 01 02 00 0a 0b 0c 0d  78 79 63 00 00 00 00 00   Z.......xyc.....
        >>> b.set_dsm_range(1, 0x1234567887654321, 0xabcdef12)
        >>> b.dump(64)
        buffer
        00000000  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  ................
        00000010  00 00 00 00 12 ef cd ab  21 43 65 87 78 56 34 12  ........!Ce.xV4.
        00000020  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  ................
        00000030  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00   ................
```
    """

    cdef void* ptr
    cdef size_t size
    cdef char* name
    cdef unsigned long phys_addr

    def __cinit__(self, size=4096, name="buffer"):
        assert size > 0, "0 is not valid size"

        # copy python string to c string
        name_len = (len(name)+1)*sizeof(char)
        self.name = <char*>PyMem_Malloc(name_len)
        if not self.name:
            raise MemoryError()
        memset(self.name, 0, name_len)
        strncpy(self.name, name.encode('ascii'), len(name))

        # buffer init
        self.size = size
        self.ptr = d.buffer_init(size, &self.phys_addr)
        if self.ptr is NULL:
            raise MemoryError()

    def __dealloc__(self):
        if self.name is not NULL:
            PyMem_Free(self.name)

        if self.ptr is not NULL:
            d.buffer_fini(self.ptr)

    @property
    def phys_addr(self):
        return self.phys_addr
    
    def dump(self, size=None):
        """print the buffer content

        Args:
            size: the size of the buffer to print,
                  default: None, means to print the whole buffer
        """
        if self.ptr and self.size:
            # 0 size means print the whole buffer
            if size is None or size > self.size:
                size = self.size
            d.log_buf_dump(self.name, self.ptr, size)

    def data(self, byte_end, byte_begin=None, type=int):
        """get field in the buffer. Little endian for integers.

        Args:
            byte_end (int): the end byte number of this field, which is specified in NVMe spec. Included.
            byte_begin (int): the begin byte number of this field, which is specified in NVMe spec. It can be omitted if begin is the same as end when the field has only 1 byte. Included.
                              default: None, means only get 1 byte defined in byte_end
            type (type): the type of the field. It should be int or str.
                         default: int, convert to integer python object

        Rets:
            (int or str): the data in the specified field
        """

        if byte_begin is None:
            byte_begin = byte_end

        if type is int:
            return int.from_bytes(self[byte_begin:byte_end+1], 'little')
        else:
            assert type is str, "identify data should be int or str"
            return str(self[byte_begin:byte_end+1], "ascii").rstrip()

    def __len__(self):
        return self.size

    def __repr__(self):
        return '<buffer name: %s>' % str(self.name, "ascii")

    def __getitem__(self, index):
        if isinstance(index, slice):
            return bytes([self[i] for i in range(*index.indices(len(self)))])
        elif isinstance(index, int):
            return (<unsigned char*>self.ptr)[index]
        else:
            raise TypeError()

    def __setitem__(self, index, value):
        if isinstance(index, slice):
            start = 0 if index.start is None else index.start
            for i, d in enumerate(value):
                self[i+start] = d
        elif isinstance(index, int):
            (<unsigned char*>self.ptr)[index] = value
        else:
            raise TypeError()

    def set_dsm_range(self, index, lba, lba_count):
        """set dsm ranges in the buffer, for dsm/deallocation (a.ka trim) commands

        Args:
            index (int): the index of the dsm range to set
            lba (int): the start lba of the range
            lba_count (int): the lba count of the range
        """
        self[index*16:(index+1)*16] = struct.pack("<LLQ", 0, lba_count, lba)


cdef class Subsystem(object):
    """Subsystem class. Prefer to use fixture "subsystem" in test scripts.

    Args:
        nvme (Controller): the nvme controller object of that subsystem
    """

    cdef Controller _nvme

    def __cinit__(self, Controller nvme):
        self._nvme = nvme

    def power_cycle(self, sec=10):
        """power off and on in seconds

        Args:
            sec (int): the seconds between power off and power on
        """

        # use S3/suspend to power off nvme device, and use rtc to power on again
        logging.info("power off nvme device for %d seconds" % sec)
        subprocess.call("sudo echo deep > /sys/power/mem_sleep", shell=True)
        subprocess.call("sudo rtcwake -m mem -s %d 1>/dev/null 2>/dev/null" % sec, shell=True)
        #subprocess.call("sudo echo mem >/sys/power/state", shell=True)
        logging.info("power is back")

        #reset driver
        self._nvme._reinit()

    def shutdown_notify(self, abrupt=False):
        """notify nvme subsystem a shutdown event through register cc.chn

        Args:
            abrupt (bool): it will be an abrupt shutdown (return immediately) or clean shutdown (wait shutdown completely)
        """

        # cc.chn
        cc = self._nvme[0x14]
        if abrupt:
            cc = cc | 0x8000
        else:
            cc = cc | 0x4000
        self._nvme[0x14] = cc

        if not abrupt:
            logging.debug("waiting csts.shst ...")
            while (self._nvme[0x1c] & 0xc) != 0x8: pass

    def reset(self):
        """reset the nvme subsystem through register nssr.nssrc"""

        # nssr.nssrc: nvme subsystem reset
        logging.debug("nvme subsystem reset by NSSR.NSSRC")
        self._nvme[0x20] = 0x4E564D65  # "NVMe"
        self._nvme._reinit()


cdef class Pcie(object):
    """Pcie class. Prefer to use fixture "pcie" in test scripts

    Args:
        nvme (Controller): the nvme controller object of that subsystem
    """

    cdef d.pcie * _pcie
    cdef Controller _nvme

    def __cinit__(self, Controller nvme):
        self._nvme = nvme
        self._pcie = d.pcie_init(nvme._ctrlr)
        if self._pcie is NULL:
            raise SystemError()

    def __getitem__(self, index):
        """access pcie config space by bytes."""
        cdef unsigned char value

        if isinstance(index, slice):
            return [self[ii] for ii in range(index.stop)[index]]
        elif isinstance(index, int):
            d.pcie_cfg_read8(self._pcie, & value, index)
            return value
        else:
            raise TypeError()

    def __setitem__(self, index, value):
        """set pcie config space by bytes."""
        if isinstance(index, int):
            d.pcie_cfg_write8(self._pcie, value, index)
        else:
            raise TypeError()

    def register(self, offset, byte_count):
        """access registers in pcie config space, and get its integer value.

        Args:
            offset (int): the offset (in bytes) of the register in the config space
            byte_count (int): the size (in bytes) of the register

        Rets:
            (int): the value of the register
        """

        assert byte_count <= 8, "support uptp 8-byte PCIe register access"
        value = bytes(self[offset:offset+byte_count])
        return int.from_bytes(value, 'little')

    def reset(self):
        """reset this pcie device"""

        vid = self.register(0, 2)
        did = self.register(2, 2)
        vdid = '%04x %04x' % (vid, did)
        nvme = 'nvme'
        spdk = 'uio_pci_generic'
        bdf = '0000:' + self._nvme._bdf.decode('utf-8')
        logging.debug("pci reset %s on %s" % (vdid, bdf))

        # reset
        subprocess.call('echo "%s" > "/sys/bus/pci/devices/%s/driver/remove_id" 2> /dev/null || true' % (vid, bdf), shell=True)
        subprocess.call('echo "%s" > "/sys/bus/pci/devices/%s/driver/unbind" 2> /dev/null || true' % (bdf, bdf), shell=True)
        subprocess.call('echo "%s" > "/sys/bus/pci/drivers/%s/new_id" 2> /dev/null || true' % (vid, nvme), shell=True)
        subprocess.call('echo "%s" > "/sys/bus/pci/drivers/%s/bind" 2> /dev/null || true' % (bdf, nvme), shell=True)

        # config
        subprocess.call('echo "%s" > "/sys/bus/pci/devices/%s/driver/remove_id" 2> /dev/null || true' % (vid, bdf), shell=True)
        subprocess.call('echo "%s" > "/sys/bus/pci/devices/%s/driver/unbind" 2> /dev/null || true' % (bdf, bdf), shell=True)
        subprocess.call('echo "%s" > "/sys/bus/pci/drivers/%s/new_id" 2> /dev/null || true' % (vid, spdk), shell=True)
        subprocess.call('echo "%s" > "/sys/bus/pci/drivers/%s/bind" 2> /dev/null || true' % (bdf, spdk), shell=True)

        # reset driver: namespace is init by every test, so no need reinit
        self._nvme._reinit()


class NvmeEnumerateError(Exception):
    pass


class NvmeDeletionError(Exception):
    pass


cdef class Controller(object):
    """Controller class. Prefer to use fixture "nvme0" in test scripts.

    Args:
        bdf (bytes): the bus/device/function address of the DUT, example: b'01:00.0'.

    Example:
```python
        >>> n = Controller(b'01:00.0')
        >>> hex(n[0])     # CAP register
        '0x28030fff'
        >>> hex(n[0x1c])  # CSTS register
        '0x1'
        >>> n.id_data(23, 4, str)
        'TW0546VPLOH007A6003Y'
        >>> n.supports(0x18)
        False
        >>> n.supports(0x80)
        True
        >>> id_buf = Buffer()
        >>> n.identify().waitdone()
        >>> id_buf.dump(64)
        buffer
        00000000  a4 14 4b 1b 54 57 30 35  34 36 56 50 4c 4f 48 30  ..K.TW0546VPLOH0
        00000010  30 37 41 36 30 30 33 59  43 41 33 2d 38 44 32 35  07A6003YCA3-8D25
        00000020  36 2d 51 31 31 20 4e 56  4d 65 20 4c 49 54 45 4f  6-Q11 NVMe LITEO
        00000030  4e 20 32 35 36 47 42 20  20 20 20 20 20 20 20 20   N 256GB
        >>> n.cmdlog(2)
        driver.c:1451:log_cmd_dump: *NOTICE*: dump qpair 0, latest tail in cmdlog: 1
        driver.c:1462:log_cmd_dump: *NOTICE*: index 0, 2018-10-14 14:52:25.533708
        nvme_qpair.c: 118:nvme_admin_qpair_print_command: *NOTICE*: IDENTIFY (06) sqid:0 cid:0 nsid:1 cdw10:00000001 cdw11:00000000
        driver.c:1469:log_cmd_dump: *NOTICE*: index 0, 2018-10-14 14:52:25.534030
        nvme_qpair.c: 306:nvme_qpair_print_completion: *NOTICE*: SUCCESS (00/00) sqid:0 cid:95 cdw0:0 sqhd:0142 p:1 m:0 dnr:0
        driver.c:1462:log_cmd_dump: *NOTICE*: index 1, 1970-01-01 07:30:00.000000
        nvme_qpair.c: 118:nvme_admin_qpair_print_command: *NOTICE*: DELETE IO SQ (00) sqid:0 cid:0 nsid:0 cdw10:00000000 cdw11:00000000
        driver.c:1469:log_cmd_dump: *NOTICE*: index 1, 1970-01-01 07:30:00.000000
        nvme_qpair.c: 306:nvme_qpair_print_completion: *NOTICE*: SUCCESS (00/00) sqid:0 cid:0 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
```
    """

    cdef d.ctrlr * _ctrlr
    cdef char _bdf[20]
    cdef Buffer hmb_buf
    
    def __cinit__(self, bdf):
        strncpy(self._bdf, bdf, strlen(bdf)+1)
        self._create()

    def __dealloc__(self):
        self._close()

    def _reinit(self):
        logging.debug("to re-initialize nvme: %s", self._bdf)
        self._close()
        self._create()

    def _create(self):
        self._ctrlr = d.nvme_init(self._bdf)
        if self._ctrlr is NULL:
            raise NvmeEnumerateError(f"fail to create the controller")
        d.nvme_register_timeout_cb(self._ctrlr, timeout_driver_cb, _cTIMEOUT)
        self.register_aer_cb(None)
        logging.debug("nvme initialized: %s", self._bdf)

    def enable_hmb(self):
        # init hmb function
        hmb_size = self.id_data(275, 272)
        if hmb_size:
            self.hmb_buf = Buffer(4096*hmb_size)
            hmb_list_buf = Buffer(4096)
            hmb_list_buf[0:8] = self.hmb_buf.phys_addr.to_bytes(8, 'little')
            hmb_list_buf[8:12] = hmb_size.to_bytes(4, 'little')
            hmb_list_phys = hmb_list_buf.phys_addr
            self.setfeatures(0x0d, 1, hmb_size,
                             hmb_list_phys&0xffffffff,
                             hmb_list_phys>>32, 1).waitdone()

    def disable_hmb(self):
        self.setfeatures(0x0d, 0).waitdone()

    @property
    def mdts(self):
        """max data transfer size"""
        page_size = (1UL<<(12+((self[4]>>16)&0xf)))
        mdts_shift = self.id_data(77)
        if mdts_shift == 0:
            return 512*(1UL<<16)
        else:
            return page_size*(1UL<<mdts_shift)
    
    def _close(self):
        if self._ctrlr is not NULL:
            ret = d.nvme_fini(self._ctrlr)
            if ret != 0:
                raise NvmeDeletionError(f"fail to close the controller, check if any qpair is not deleted: {ret}")
            self._ctrlr = NULL

    def __getitem__(self, index):
        """read nvme registers in BAR memory space by dwords."""

        cdef unsigned int value

        assert index % 4 == 0, "only support 4-byte aligned NVMe register read"

        if isinstance(index, int):
            d.nvme_get_reg32(self._ctrlr, index, & value)
            if ~value == 0:
                raise SystemError()
            return value
        else:
            raise TypeError()

    def __setitem__(self, index, value):
        """write nvme registers in BAR memory space by dwords."""

        assert index % 4 == 0, "only support 4-byte aligned NVMe register write"

        if isinstance(index, int):
            d.nvme_set_reg32(self._ctrlr, index, value)
        else:
            raise TypeError()

    def cmdlog(self, count=0):
        """print recent commands and their completions.

        Args:
            count (int): the number of commands to print
                         default: 0, to print the whole cmdlog
        """

        d.log_cmd_dump_admin(self._ctrlr, count)

    def reset(self):
        """controller reset: cc.en 1 => 0 => 1

        Notices:
            Test scripts should delete all io qpairs before reset!
        """

        cc = self[0x14]
        assert (cc & 1) == 1, "cc.en is not 1 before reset"

        logging.debug("cc.en 1=>0")
        self[0x14] = cc & 0xfffffffe
        while (self[0x1c] & 1) == 1:
            logging.debug("wait csts.rdy, 0x%x" % self[0x1c])

        logging.debug("cc.en 0=>1")
        self[0x14] = cc | 1
        while (self[0x1c] & 1) == 0:
            logging.debug("wait csts.rdy, 0x%x" % self[0x1c])

        # reset driver
        self._reinit()

    def cmdname(self, opcode):
        """get the name of the admin command

        Args:
            opcode (int): the opcode of the admin command

        Rets:
            (str): the command name
        """

        assert opcode < 256
        name = d.cmd_name(opcode, 0)
        return name.decode('ascii')

    def supports(self, opcode):
        """check if the admin command is supported

        Args:
            opcode (int): the opcode of the admin command

        Rets:
            (bool): if the command is supported
        """

        assert opcode < 256*2 # *2 for nvm command set
        logpage_buf = Buffer(4096)
        self.getlogpage(5, logpage_buf).waitdone()
        return logpage_buf.data((opcode+1)*4-1, opcode*4) != 0

    def waitdone(self, expected=1):
        """sync until expected commands completion

        Args:
            expected (int): expected commands to complete
                            default: 1

        Notices:
            Do not call this function in commands callback functions.
        """

        reaped = 0

        global _reentry_flag
        assert _reentry_flag is False, f"cannot re-entry waitdone() functions which may be caused by waitdone in callback functions, {_reentry_flag}"
        _reentry_flag = True

        logging.debug("to reap %d admin commands" % expected)
        # some admin commands need long timeout limit, like: format,
        signal.alarm(_cTIMEOUT_wrap)
        while reaped < expected:
            # wait admin Q pair done
            reaped += d.nvme_wait_completion_admin(self._ctrlr)

            # Since signals are delivered asynchronously at unpredictable
            # times, it is problematic to run any meaningful code directly
            # from the signal handler. Therefore, Python queues incoming
            # signals. The queue is processed later as part of the interpreter
            # loop. If your code is fully compiled, interpreter loop is never
            # executed and Python has no chance to check and run queued signal
            # handlers.
            # - from: https://stackoverflow.com/questions/16769870/cython-python-and-keyboardinterrupt-ignored
            PyErr_CheckSignals()
        signal.alarm(0)

        # in admin queue, may reap more than expected, because driver
        # will get admin CQ as many as possible
        assert reaped >= expected, \
            "not reap the exact completions! reaped %d, expected %d" % (reaped, expected)
        _reentry_flag = False

    def abort(self, cid, sqid=0, cb=None):
        """abort admin commands

        Args:
            cid (int): command id of the command to be aborted
            sqid (int): sq id of the command to be aborted
                        default: 0, to abort the admin command
            cb (function): callback function called at completion
                           default: None

        Rets:
            self (Controller)
        """

        self.send_admin_raw(None, 0x8,
                            nsid=0,
                            cdw10=(cid<<16)+sqid,
                            cdw11=0,
                            cdw12=0,
                            cdw13=0,
                            cdw14=0,
                            cdw15=0,
                            cb_func=cmd_cb,
                            cb_arg=<void*>cb)
        return self

    def identify(self, buf, nsid=1, cns=1, cb=None):
        """identify admin command

        Args:
            buf (Buffer): the buffer to hold the identify data
            nsid (int): nsid field in the command
                        default: 1
            cns (int): cns field in the command
                       default: 1
            cb (function): callback function called at completion
                           default: None

        Rets:
            self (Controller)
        """

        self.send_admin_raw(buf, 0x6,
                            nsid=nsid,
                            cdw10=cns,
                            cdw11=0,
                            cdw12=0,
                            cdw13=0,
                            cdw14=0,
                            cdw15=0,
                            cb_func=cmd_cb,
                            cb_arg=<void*>cb)
        return self

    def id_data(self, byte_end, byte_begin=None, type=int, nsid=0, cns=1):
        """get field in controller identify data

        Args:
            byte_end (int): the end byte number of this field, which is specified in NVMe spec. Included.
            byte_begin (int): the begin byte number of this field, which is specified in NVMe spec. It can be omitted if begin is the same as end when the field has only 1 byte. Included.
                              default: None, means only get 1 byte defined in byte_end
            type (type): the type of the field. It should be int or str.
                         default: int, convert to integer python object

        Rets:
            (int or str): the data in the specified field
        """

        id_buf = Buffer(4096)
        self.identify(id_buf, nsid, cns).waitdone()
        return id_buf.data(byte_end, byte_begin, type)

    def getfeatures(self, fid, cdw11=0, cdw12=0, cdw13=0, cdw14=0, cdw15=0,
                    sel=0, buf=None, cb=None):
        """getfeatures admin command

        Args:
            fid (int): feature id
            cdw11 (int): cdw11 in the command
                         default: 0
            sel (int): sel field in the command
                       default: 0
            buf (Buffer): the buffer to hold the feature data
                          default: None
            cb (function): callback function called at completion
                           default: None

        Rets:
            self (Controller)
        """
        self.send_admin_raw(buf, 0xA,
                            nsid=1,
                            cdw10=(sel << 8)+fid,
                            cdw11=cdw11,
                            cdw12=cdw12,
                            cdw13=cdw13,
                            cdw14=cdw14,
                            cdw15=cdw15,
                            cb_func=cmd_cb,
                            cb_arg=<void*>cb)
        return self

    def setfeatures(self, fid, cdw11=0, cdw12=0, cdw13=0, cdw14=0, cdw15=0,
                    sv=0, buf=None, cb=None):
        """setfeatures admin command

        Args:
            fid (int): feature id
            cdw11 (int): cdw11 in the command
                         default: 0
            sv (int): sv field in the command
                      default: 0
            buf (Buffer): the buffer to hold the feature data
                          default: None
            cb (function): callback function called at completion
                           default: None

        Rets:
            self (Controller)
        """

        self.send_admin_raw(buf, 0x9,
                            nsid=0xffffffff,
                            cdw10=(sv << 31)+fid,
                            cdw11=cdw11,
                            cdw12=cdw12,
                            cdw13=cdw13,
                            cdw14=cdw14,
                            cdw15=cdw15,
                            cb_func=cmd_cb,
                            cb_arg=<void*>cb)
        return self

    def getlogpage(self, lid, buf, size=None, offset=0, nsid=0xffffffff, cb=None):
        """getlogpage admin command

        Args:
            lid (int): Log Page Identifier
            buf (Buffer): buffer to hold the log page
            size (int): size (in byte) of data to get from the log page,
                        default: None, means the size is the same of the buffer
            offset (int): the location within a log page
            nsid (int): nsid field in the command
                        default: 0xffffffff
            cb (function): callback function called at completion
                           default: None

        Rets:
            self (Controller)
        """

        if size is None:  size = len(buf)  # the same size of buffer
        assert size%4 == 0, "size must be dword aligned"
        assert offset%4 == 0, "offset must be dword aligned"

        dwords = (size >> 2) - 1  # zero-based dword number
        assert dwords >= 0
        assert dwords < 0x1_0000_0000, "32-bit field"
        assert offset >= 0
        assert offset < 0x1_0000_0000_0000_0000, "64-bit field"

        self.send_admin_raw(buf, 0x2,
                            nsid=nsid,
                            cdw10=((dwords & 0xffff) << 16) + lid,
                            cdw11=dwords >> 16,
                            cdw12=offset,
                            cdw13=offset >> 32,
                            cdw14=0,
                            cdw15=0,
                            cb_func=cmd_cb,
                            cb_arg=<void*>cb)
        return self

    def format(self, lbaf=0, ses=0, nsid=1, cb=None):
        """format admin command

        Args:
            lbaf (int): lbaf (lba format) field in the command
                        default: None, to find the 512B LBA format
            ses (int): ses field in the command
            nsid (int): nsid field in the command
                        default: 1
            cb (function): callback function called at completion
                           default: None

        Rets:
            self (Controller)
        """

        assert ses < 8, "invalid format ses"
        assert lbaf < 16, "invalid format lbaf"

        logging.info(f"format, ses {ses}, lbaf {lbaf}, nsid {nsid}")
        d.crc32_clear(0, 0, True, False)
        self.send_admin_raw(None, 0x80,
                            nsid=nsid,
                            cdw10=(ses<<9) + lbaf,
                            cdw11=0,
                            cdw12=0,
                            cdw13=0,
                            cdw14=0,
                            cdw15=0,
                            cb_func=cmd_cb,
                            cb_arg=<void*>cb)
        return self

    def sanitize(self, option=2, pattern=0, cb=None):
        """sanitize admin command

        Args:
            option (int): sanitize option field in the command
            pattern (int): pattern field in the command for overwrite method
                           default: 0x5aa5a55a
            cb (function): callback function called at completion
                           default: None

        Rets:
            self (Controller)
        """

        logging.info(f"sanitize, option {option}")
        d.crc32_clear(0, 0, True, False)
        self.send_admin_raw(None, 0x84,
                            nsid=0,
                            cdw10=option,
                            cdw11=pattern,
                            cdw12=0,
                            cdw13=0,
                            cdw14=0,
                            cdw15=0,
                            cb_func=cmd_cb,
                            cb_arg=<void*>cb)
        return self

    def dst(self, stc=1, nsid=0xffffffff, cb=None):
        """device self test (DST) admin command

        Args:
            stc (int): selftest code (stc) field in the command
            nsid (int): nsid field in the command
                        default: 0xffffffff
            cb (function): callback function called at completion
                           default: None

        Rets:
            self (Controller)
        """

        self.send_admin_raw(None, 0x14,
                            nsid=nsid,
                            cdw10=stc,
                            cdw11=0,
                            cdw12=0,
                            cdw13=0,
                            cdw14=0,
                            cdw15=0,
                            cb_func=cmd_cb,
                            cb_arg=<void*>cb)
        return self

    def fw_download(self, buf, offset, size=None, cb=None):
        """firmware download admin command

        Args:
            buf (Buffer): the buffer to hold the firmware data
            offset (int): offset field in the command
            size (int): size field in the command
                        default: None, means the size of the buffer
            cb (function): callback function called at completion
                           default: None

        Rets:
            self (Controller)
        """

        if size is None:  size = len(buf)  # the same size of buffer
        logging.debug("firmware image download, offset 0x%x, size %d" % (offset, size))
        self.send_admin_raw(buf, 0x11,
                            nsid=0,
                            cdw10=(size>>2)-1,  # zero-based dword number
                            cdw11=(offset>>2),  # unit is dword
                            cdw12=0,
                            cdw13=0,
                            cdw14=0,
                            cdw15=0,
                            cb_func=cmd_cb,
                            cb_arg=<void*>cb)
        return self

    def fw_commit(self, slot, action, cb=None):
        """firmware commit admin command

        Args:
            slot (int): firmware slot field in the command
            action (int): action field in the command
            cb (function): callback function called at completion
                           default: None

        Rets:
            self (Controller)
        """

        # no need to block invalid test parameters for DUT
        assert slot < 8, "invalid fw slot: %d" % slot
        assert action < 8, "invalid fw commit action: %d" % action

        logging.debug("firmware commit, slot %d, action %d" % (slot, action))
        self.send_admin_raw(None, 0x10,
                            nsid=0,
                            cdw10=(action<<3)+slot,
                            cdw11=0,
                            cdw12=0,
                            cdw13=0,
                            cdw14=0,
                            cdw15=0,
                            cb_func=cmd_cb,
                            cb_arg=<void*>cb)
        return self

    def downfw(self, filename, slot=0, action=1):
        """firmware download utility: by 4K, and activate in next reset

        Args:
            filename (str): the pathname of the firmware binary file to download
            slot (int): firmware slot field in the command
                        default: 0, decided by device
            cb (function): callback function called at completion
                           default: None

        Rets:
        """

        logging.info("download firmware image %s to slot %d and activate" % (filename, slot))
        with open(filename, "rb") as f:
            buf = Buffer(4096)
            for i, chunk in enumerate(iter(lambda: f.read(4096), b'')):
                buf[:] = chunk
                self.fw_download(buf, 4096*i).waitdone()
        self.fw_commit(slot, action).waitdone()
        logging.info("download firmware completed")

    def aer(self, cb=None):
        """asynchorous event request admin command.

        Not suggested to use this command in scripts because driver manages to send and monitor aer commands. Scripts should register an aer callback function if it wants to handle aer.

        Args:
            cb (function): callback function called at completion
                           default: None

        Rets:
            self (Controller)
        """

        self.send_admin_raw(None, 0xc,
                            nsid=0,
                            cdw10=0,
                            cdw11=0,
                            cdw12=0,
                            cdw13=0,
                            cdw14=0,
                            cdw15=0,
                            cb_func=cmd_cb,
                            cb_arg=<void*>cb)
        return self

    def register_aer_cb(self, func):
        """register aer callback to driver.

        It is recommended to use fixture aer(func) in pytest scripts.
        When aer is triggered, the python callback function will
        be called. It is unregistered by aer fixture when test finish.

        Args:
            func (function): callback function called at aer completion
        """

        d.nvme_register_aer_cb(self._ctrlr, aer_cmd_cb, <void*>func)

    cdef int send_admin_raw(self,
                            Buffer buf,
                            unsigned int opcode,
                            unsigned int nsid,
                            unsigned int cdw10,
                            unsigned int cdw11,
                            unsigned int cdw12,
                            unsigned int cdw13,
                            unsigned int cdw14,
                            unsigned int cdw15,
                            d.cmd_cb_func cb_func,
                            void* cb_arg):
        cdef void* ptr
        cdef size_t size

        if buf is None:
            ptr = NULL
            size = 0
        else:
            ptr = buf.ptr
            size = buf.size

        logging.debug("send admin command, opcode %xh" % opcode)
        ret = d.nvme_send_cmd_raw(self._ctrlr, NULL, opcode, nsid, ptr, size,
                                  cdw10, cdw11, cdw12, cdw13, cdw14, cdw15,
                                  cb_func, cb_arg)
        assert ret == 0, "error in submitting admin commands, 0x%x" % ret
        return ret


class QpairCreationError(Exception):
    pass


class QpairDeletionError(Exception):
    pass


cdef class Qpair(object):
    """Qpair class. IO SQ and CQ are combinded as qpairs.

    Args:
        nvme (Controller): controller where to create the queue
        depth (int): SQ/CQ queue depth
        prio (int): when Weighted Round Robin is enabled, specify SQ priority here
    """

    cdef d.qpair * _qpair

    def __cinit__(self, Controller nvme,
                  unsigned int depth,
                  unsigned int prio=0):
        # create CQ and SQ
        if depth < 2:
            raise QpairCreationError("depth should >= 2")
            
        self._qpair = d.qpair_create(nvme._ctrlr, prio, depth)
        if self._qpair is NULL:
            raise QpairCreationError("qpair create fail")

    def __dealloc__(self):
        if self._qpair is not NULL:
            if d.qpair_free(self._qpair) != 0:
                raise QpairDeletionError()
            self._qpair = NULL

    def __repr__(self):
        return "<qpair: %d>" % self.sqid

    @property
    def sqid(self):
        return d.qpair_get_id(self._qpair)

    def cmdlog(self, count=0):
        """print recent IO commands and their completions in this qpair.

        Args:
            count (int): the number of commands to print
                         default: 0, to print the whole cmdlog
        """

        d.log_cmd_dump(self._qpair, count)

    def waitdone(self, expected=1):
        """sync until expected commands completion

        Args:
            expected (int): expected commands to complete
                            default: 1

        Notices:
            Do not call this function in commands callback functions.
        """

        reaped = 0

        global _reentry_flag
        assert _reentry_flag is False, f"cannot re-entry waitdone() functions which may be caused by waitdone in callback functions, {_reentry_flag}"
        _reentry_flag = True

        logging.debug("to reap %d io commands, sqid %d" % (expected, self.sqid))
        signal.alarm(_cTIMEOUT_wrap)
        while reaped < expected:
            # wait IO Q pair done, max 8 cpl in one time
            max_to_reap = (expected-reaped) % 8
            reaped += d.qpair_wait_completion(self._qpair, max_to_reap)
            PyErr_CheckSignals()
        signal.alarm(0)

        assert reaped == expected, \
            "not reap the exact completions! reaped %d, expected %d" % (reaped, expected)
        _reentry_flag = False


class NamespaceCreationError(Exception):
    pass


class NamespaceDeletionError(Exception):
    pass


cdef class Namespace(object):
    """Namespace class. Prefer to use fixture "nvme0n1" in test scripts.

    Args:
        nvme (Controller): controller where to create the queue
        nsid (int): nsid of the namespace
    """

    cdef d.namespace * _ns
    cdef char _bdf[8]
    cdef unsigned int _nsid
    cdef unsigned int sector_size
    cdef Controller _nvme

    def __cinit__(self, Controller nvme, unsigned int nsid=1):
        logging.debug("initialize namespace nsid %d" % nsid)
        self._nvme = nvme
        strncpy(self._bdf, nvme._bdf, 8)
        self._nsid = nsid
        self._ns = d.ns_init(nvme._ctrlr, nsid)
        if self._ns is NULL:
            raise NamespaceCreationError()
        self.sector_size = d.ns_get_sector_size(self._ns)

    def close(self):
        """close namespace to release it resources in host memory.

        Notice:
            Release resources explictly, del is not garentee to call __dealloc__.
            Fixture nvme0n1 uses this function, and prefer to use fixture in scripts, instead of calling this function directly.
        """
        logging.debug("close namespace")
        if self._ns is not NULL:
            if d.ns_fini(self._ns) != 0:
                raise NamespaceDeletionError()
            self._ns = NULL

    @property
    def nsid(self):
        """id of the namespace"""
        return self._nsid

    @property
    def capacity(self):
        """bytes of namespace capacity"""
        return self.id_data(63, 48)

    def cmdname(self, opcode):
        """get the name of the IO command

        Args:
            opcode (int): the opcode of the IO command

        Rets:
            (str): the command name
        """

        assert opcode < 256
        name = d.cmd_name(opcode, 1)
        return name.decode('ascii')

    def supports(self, opcode):
        """check if the IO command is supported

        Args:
            opcode (int): the opcode of the IO command

        Rets:
            (bool): if the command is supported
        """

        assert opcode < 256
        return self._nvme.supports(256+opcode)

    def id_data(self, byte_end, byte_begin=None, type=int):
        """get field in namespace identify data

        Args:
            byte_end (int): the end byte number of this field, which is specified in NVMe spec. Included.
            byte_begin (int): the begin byte number of this field, which is specified in NVMe spec. It can be omitted if begin is the same as end when the field has only 1 byte. Included.
                              default: None, means only get 1 byte defined in byte_end
            type (type): the type of the field. It should be int or str.
                         default: int, convert to integer python object

        Rets:
            (int or str): the data in the specified field
        """

        return self._nvme.id_data(byte_end, byte_begin, type, self._nsid, 0)

    def get_lba_format(self, data_size=512, meta_size=0):
        """find the lba format by its data size and meta data size

        Args:
            data_size (int): data size
                             default: 512
            meta_size (int): meta data size
                             default: 0

        Rets:
            (int or None): the lba format has the specified data size and meta data size
        """
        # find the lba format with 512B size
        for fid in range(16):
            format_support = self.id_data(128+fid*4+3, 128+fid*4)
            if data_size == (1<<((format_support>>16)&0xff)) and \
               meta_size == (format_support&0xffff):
                return fid
    
    def ioworker(self, io_size, lba_align, lba_random,
                 read_percentage, time=0, qdepth=64,
                 region_start=0, region_end=0xffff_ffff_ffff_ffff,
                 iops=0, io_count=0, lba_start=0, qprio=0,
                 output_io_per_second=None, output_percentile_latency=None):
        """workers sending different read/write IO on different CPU cores.

        User defines IO characteristics in parameters, and then the ioworker
        executes without user intervesion, until the test is completed. IOWorker
        returns some statistic data at last.

        User can start multiple IOWorkers, and they will be binded to different
        CPU cores. Each IOWorker creates its own Qpair, so active IOWorker counts
        is limited by maximum IO queues that DUT can provide.

        Each ioworker can run upto 24 hours.

        Args:
            io_size (short): IO size, unit is LBA
            lba_align (short): IO alignment, unit is LBA
            lba_random (bool): True if sending IO with random starting LBA
            read_percentage (int): sending read/write mixed IO, 0 means write only, 100 means read only
            time (int): specified maximum seconds of the IOWorker
                        default:0, no limit (upto 24hr)
            qdepth (int): queue depth of the Qpair created by the IOWorker
                          default: 64
            region_start (long): sending IO in the specified LBA region, start
                                 default: 0
            region_end (long): sending IO in the specified LBA region, end but not include
                               default: 0xffff_ffff_ffff_ffff
            iops (int): specified maximum IOPS. IOWorker throttles the sending IO speed.
                        default: 0, no limit
            io_count (long): specified maximum IO counts to send.
                             default: 0, no limit
            lba_start (long): the LBA address of the first command.
                              default: 0, means start from region_start
            qprio (int): SQ priority.
                         default: 0, for default Round Robin arbitration
            output_io_per_second (list): list to hold the output data of io_per_second.
                                         default: None, not to collect the data
            output_percentile_latency (dict): dict of io counter on different percentile latency. Dict key is the percentage, and the value is the latency in ms.
                                              default: None, not to collect the data

        Rets:
            ioworker instance

        Notice:
            use ioworker.progress to get the realtime io counters
        """

        assert not (time==0 and io_count==0), "when to stop the ioworker?"
        assert qdepth>0 and qdepth<=1024, "support qdepth upto 1024"
        assert qdepth <= (self._nvme[0]&0xffff) + 1, "qdepth is larger than specification"  
        
        pciaddr = self._bdf
        nsid = self._nsid
        return _IOWorker(pciaddr, nsid, lba_start, io_size, lba_align,
                         lba_random, region_start, region_end,
                         read_percentage, iops, io_count, time, qdepth+1, qprio,
                         output_io_per_second, output_percentile_latency)

    def read(self, qpair, buf, lba, lba_count=1, io_flags=0, cb=None):
        """read IO command

        Args:
            qpair (Qpair): use the qpair to send this command
            buf (Buffer): the data buffer of the command, meta data is not supported.
            lba (int): the starting lba address, 64 bits
            lba_count (int): the lba count of this command, 16 bits
            io_flags (int): io flags defined in NVMe specification, 16 bits
                            default: 0
            cb (function): callback function called at completion
                           default: None

        Returns:
            qpair (Qpair): the qpair used to send this command, for ease of chained call

        Raises:
            SystemError: the read command fails

        Notices:
            buf cannot be released before the command completes.
        """

        logging.debug(f"read, lba {lba}, lba_count {lba_count}")
        assert buf is not None, "no buffer allocated"
        if 0 != self.send_read_write(True, qpair, buf, lba, lba_count,
                                     io_flags, cmd_cb, <void*>cb):
            raise SystemError()
        return qpair

    def write(self, qpair, buf, lba, lba_count=1, io_flags=0, cb=None):
        """write IO command

        Args:
            qpair (Qpair): use the qpair to send this command
            buf (Buffer): the data buffer of the write command, meta data is not supported.
            lba (int): the starting lba address, 64 bits
            lba_count (int): the lba count of this command, 16 bits
            io_flags (int): io flags defined in NVMe specification, 16 bits
                            default: 0
            cb (function): callback function called at completion
                           default: None

        Returns:
            qpair (Qpair): the qpair used to send this command, for ease of chained call

        Raises:
            SystemError: the write command fails

        Notices:
            buf cannot be released before the command completes.
        """

        assert buf is not None, "no buffer allocated"

        if 0 != self.send_read_write(False, qpair, buf, lba, lba_count,
                                     io_flags, cmd_cb, <void*>cb):
            raise SystemError()

        return qpair

    def dsm(self, qpair, buf, range_count, attribute=0x4, cb=None):
        """data-set management IO command

        Args:
            qpair (Qpair): use the qpair to send this command
            buf (Buffer): the buffer of the lba ranges. Use buffer.set_dsm_range to prepare the buffer.
            range_count (int): the count of lba ranges in the buffer
            attribute (int): attribute field of the command
                             default: 0x4, as deallocation
            cb (function): callback function called at completion
                           default: None

        Returns:
            qpair (Qpair): the qpair used to send this command, for ease of chained call

        Raises:
            SystemError: the command fails

        Notices:
            buf cannot be released before the command completes.
        """

        assert buf is not None, "no buffer allocated"
        self.send_io_raw(qpair, buf, 9, self._nsid,
                         range_count-1, attribute,
                         0, 0, 0, 0,
                         cmd_cb, <void*>cb)
        return qpair

    def compare(self, qpair, buf, lba, lba_count, io_flags=0, cb=None):
        """compare IO command

        Args:
            qpair (Qpair): use the qpair to send this command
            buf (Buffer): the data buffer of the command, meta data is not supported.
            lba (int): the starting lba address, 64 bits
            lba_count (int): the lba count of this command, 16 bits
            io_flags (int): io flags defined in NVMe specification, 16 bits
                            default: 0
            cb (function): callback function called at completion
                           default: None

        Returns:
            qpair (Qpair): the qpair used to send this command, for ease of chained call

        Raises:
            SystemError: the command fails

        Notices:
            buf cannot be released before the command completes.
        """

        assert buf is not None, "no buffer allocated"

        self.send_io_raw(qpair, buf, 5, self._nsid,
                         lba, lba>>32,
                         (lba_count-1)+(io_flags<<16),
                         0, 0, 0,
                         cmd_cb, <void*>cb)
        return qpair

    def flush(self, qpair, cb=None):
        """flush IO command

        Args:
            qpair (Qpair): use the qpair to send this command
            cb (function): callback function called at completion
                           default: None

        Returns:
            qpair (Qpair): the qpair used to send this command, for ease of chained call

        Raises:
            SystemError: the command fails
        """

        self.send_io_raw(qpair, None, 0, self._nsid,
                         0, 0, 0, 0, 0, 0,
                         cmd_cb, <void*>cb)
        return qpair

    def write_uncorrectable(self, qpair, lba, lba_count, cb=None):
        """write uncorrectable IO command

        Args:
            qpair (Qpair): use the qpair to send this command
            lba (int): the starting lba address, 64 bits
            lba_count (int): the lba count of this command, 16 bits
            cb (function): callback function called at completion
                           default: None

        Returns:
            qpair (Qpair): the qpair used to send this command, for ease of chained call

        Raises:
            SystemError: the command fails
        """

        d.crc32_clear(lba, lba_count, False, True)
        self.send_io_raw(qpair, None, 4, self._nsid,
                         lba, lba>>32,
                         lba_count-1,
                         0, 0, 0,
                         cmd_cb, <void*>cb)
        return qpair

    def write_zeroes(self, qpair, lba, lba_count, io_flags=0, cb=None):
        """write zeroes IO command

        Args:
            qpair (Qpair): use the qpair to send this command
            lba (int): the starting lba address, 64 bits
            lba_count (int): the lba count of this command, 16 bits
            io_flags (int): io flags defined in NVMe specification, 16 bits
                            default: 0
            cb (function): callback function called at completion
                           default: None

        Returns:
            qpair (Qpair): the qpair used to send this command, for ease of chained call

        Raises:
            SystemError: the command fails
        """

        d.crc32_clear(lba, lba_count, False, False)
        self.send_io_raw(qpair, None, 8, self._nsid,
                         lba, lba>>32,
                         (lba_count-1)+(io_flags<<16),
                         0, 0, 0,
                         cmd_cb, <void*>cb)
        return qpair

    cdef int send_read_write(self,
                             bint is_read,
                             Qpair qpair,
                             Buffer buf,
                             unsigned long lba,
                             unsigned short lba_count,
                             unsigned int io_flags,
                             d.cmd_cb_func cb_func,
                             void* cb_arg):
        ret = d.ns_cmd_read_write(is_read, self._ns, qpair._qpair,
                                  buf.ptr, buf.size,
                                  lba, lba_count, io_flags,
                                  cb_func, cb_arg)
        assert ret == 0, "error in submitting read write commands: 0x%x" % ret
        return ret

    cdef int send_io_raw(self,
                         Qpair qpair,
                         Buffer buf,
                         unsigned int opcode,
                         unsigned int nsid,
                         unsigned int cdw10,
                         unsigned int cdw11,
                         unsigned int cdw12,
                         unsigned int cdw13,
                         unsigned int cdw14,
                         unsigned int cdw15,
                         d.cmd_cb_func cb_func,
                         void* cb_arg):
        if buf is None:
            ptr = NULL
            size = 0
        else:
            ptr = buf.ptr
            size = buf.size

        ret = d.nvme_send_cmd_raw(self._nvme._ctrlr, qpair._qpair, opcode,
                                  nsid, ptr, size, cdw10, cdw11, cdw12,
                                  cdw13, cdw14, cdw15, cb_func, cb_arg)
        assert ret == 0, "error in submitting io commands, 0x%x" % ret
        return ret


class DotDict(dict):
    """utility class to access dict members by . operation"""
    def __init__(self, *args, **kwargs):
        super(DotDict, self).__init__(*args, **kwargs)
        self.__dict__ = self


class _IOWorker(object):
    """A process-worker executing user functions. Use its wrapper function Namespace.ioworker() in scripts. """

    # TODO: max ioworkers = ctrlr->opts.num_io_queues
    _MAX_IOWORKERS = 64
    _id_table = [False] * _MAX_IOWORKERS

    def __init__(self, pciaddr, nsid, lba_start, lba_size, lba_align,
                 lba_random, region_start, region_end,
                 read_percentage, iops, io_count, time, qdepth, qprio,
                 output_io_per_second, output_percentile_latency):
        # find the new worker id
        self.wid = next((i for i, x in enumerate(_IOWorker._id_table) if x==False), None)
        assert self.wid!=None and self.wid<_IOWorker._MAX_IOWORKERS, "cannot get valid worker id"
        logging.debug("created worker id %d" % self.wid)
        _IOWorker._id_table[self.wid] = True

        # queue for returning result
        self.q = _mp.Queue()

        # create the child process
        self.p = _mp.Process(target = self._ioworker,
                             args = (self.q, self.wid, pciaddr, nsid,
                                     lba_start, lba_size, lba_align, lba_random,
                                     region_start, region_end, read_percentage,
                                     iops, io_count, time, qdepth, qprio,
                                     output_io_per_second, output_percentile_latency))
        self.output_io_per_second = output_io_per_second
        self.output_percentile_latency = output_percentile_latency
        self.p.daemon = True

    def start(self):
        """Start the worker's process"""
        logging.debug("start ioworker")
        self.p.start()
        return self

    def find_percentile_latency(self, k, output_io_per_latency):
        target = sum(output_io_per_latency) * k // 100
        total = 0
        for l, c in enumerate(output_io_per_latency):
            total += c
            if total >= target:
                return l
        assert False, "should find the latency in the loop"

    @property
    def progress(self):
        """get the ioworker progress

        Rets:
            (io_count_sent, io_count_cplt)
        """

        status = d.ioworker_get_status(self.wid)
        return self.wid, status.io_count_sent, status.io_count_cplt

    def close(self):
        """Wait the worker's process finish

        Wait the worker process complete, and get the return report data
        """

        # get data from queue before joinging the subprocess, otherwise deadlock
        error, rets, output_io_per_second, output_io_per_latency = self.q.get()
        rets = DotDict(rets)
        self.p.join()
        logging.debug("ioworker closed")

        if error != 0:
            warnings.warn(f"ioworker host ERROR {error}")
        elif rets.error != 0:
            warnings.warn("ioworker device ERROR status: %02x/%02x" %
                          ((rets.error>>8)&0x7, rets.error&0xff))

        # transfer output table back: driver => script
        if self.output_io_per_second is not None:
            assert len(self.output_io_per_second) == 0
            self.output_io_per_second += output_io_per_second
            rets['iops_consistency'] = self.iops_consistency()

        # transfer output table back: driver => script
        if output_io_per_latency is not None:
            # latency average
            latency_sum = 0
            for us, num in enumerate(output_io_per_latency):
                latency_sum += us*num
            rets['latency_average_us'] = latency_sum//sum(output_io_per_latency)

            # distribution, group to 100 groups
            end99 = self.find_percentile_latency(99, output_io_per_latency)
            unit = (end99+99)//100
            output_io_per_latency_grouped = []
            for i in range(0, unit*100, unit):
                output_io_per_latency_grouped.append(sum(output_io_per_latency[i:i+unit]))
            logging.debug(f"end: {end99}, unit: {unit}")
            rets['latency_distribution_grouped_unit_us'] = unit
            rets['latency_distribution_grouped'] = output_io_per_latency_grouped

            # calculate percentile latencies
            for i, k in enumerate(self.output_percentile_latency):
                assert k>0 and k<100, "percentile should be in (0, 100)"
                self.output_percentile_latency[k] = self.find_percentile_latency(k, output_io_per_latency)

        # release the worker id
        if self.wid != None:
            assert self.wid < _IOWorker._MAX_IOWORKERS, "worker id is invalid"
            _IOWorker._id_table[self.wid] = False
        
        logging.debug(f"ioworker result: {rets}")
        return rets

    def iops_consistency(self, slowest_percentage=99.9):
        assert self.output_io_per_second is not None, "iops consistency data is not collected"
        assert slowest_percentage > 0, "the percentage must be larger than 0"
        assert slowest_percentage < 100, "the percentage must be smaller than 100"
        assert self.output_io_per_second, "output list is empty"
        average = sum(self.output_io_per_second)/len(self.output_io_per_second)
        index = int(len(self.output_io_per_second)*slowest_percentage)//100
        return sorted(self.output_io_per_second, reverse=True)[index]/average

    def __enter__(self):
        self.start()
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        assert exc_value is None, "ioworker exits with exception: %s" % exc_value
        self.close()
        return True

    def _ioworker(self, rqueue, wid, pciaddr, nsid, lba_start, lba_size,
                  lba_align, lba_random, region_start, region_end,
                  read_percentage, iops, io_count, time, qdepth, qprio,
                  output_io_per_second, output_percentile_latency):
        cdef d.ioworker_args args
        cdef d.ioworker_rets rets
        cdef int error = 0
        output_io_per_latency = None

        try:
            # register events in worker's processor
            # CTRL-c to exit
            signal.signal(signal.SIGINT, _interrupt_handler)
            # timeout
            signal.signal(signal.SIGALRM, _timeout_signal_handler)

            # init var
            _reentry_flag_init()
            memset(&args, 0, sizeof(args))
            memset(&rets, 0, sizeof(rets))
            assert lba_size < 0x10000, "io_size is a 16bit-field in commands"

            # create array for output data: io counter per second
            if output_io_per_second is not None:
                assert time != 0, "need time duration to collect io counter per second data"
                args.io_counter_per_second = <unsigned int*>PyMem_Malloc(time*sizeof(unsigned int))
                memset(args.io_counter_per_second, 0, time*sizeof(unsigned int))

            # create array for output data: io counter per latency
            if output_percentile_latency is not None:
                # 1-1000,000 us, all latency > 1s are counted as 1000,000us
                args.io_counter_per_latency = <unsigned int*>PyMem_Malloc(1000*1000*sizeof(unsigned int))

            # transfer agurments
            args.lba_start = lba_start
            args.lba_size = lba_size
            args.lba_align = lba_align
            args.lba_random = lba_random
            args.region_start = region_start
            args.region_end = region_end
            args.read_percentage = read_percentage
            args.iops = iops
            args.io_count = io_count
            args.seconds = time
            args.qdepth = qdepth
            args.wid = wid

            # runtime in subprocess
            nvme0 = Controller(pciaddr)
            nvme0n1 = Namespace(nvme0, nsid)
            qpair = Qpair(nvme0, max(2, qdepth), qprio)

            # ioworker main roution
            error = d.ioworker_entry(nvme0n1._ns, qpair._qpair, &args, &rets)

            # transfer back iops counter per second: c => cython
            if output_io_per_second is not None:
                for i in range(time):
                    output_io_per_second.append(args.io_counter_per_second[i])

            # transfer back percentile latency: c => cython
            if output_percentile_latency is not None:
                output_io_per_latency = []
                for i in range(1000*1000):
                    output_io_per_latency.append(args.io_counter_per_latency[i])

        except Exception as e:
            logging.warning(e)
            warnings.warn(e)
            error = -1
        finally:
            # feed return to main process
            rqueue.put((error, rets, output_io_per_second, output_io_per_latency))

            # close resources in right order
            nvme0n1.close()
            del qpair
            del nvme0n1
            del nvme0

            if args.io_counter_per_second:
                PyMem_Free(args.io_counter_per_second)

            if args.io_counter_per_latency:
                PyMem_Free(args.io_counter_per_latency)


# module init, needs root privilege
if os.geteuid() == 0:
    # CTRL-c to exit
    signal.signal(signal.SIGINT, _interrupt_handler)
    # timeout
    signal.signal(signal.SIGALRM, _timeout_signal_handler)

    _reentry_flag_init()

    # disable ASLR in kernel
    subprocess.call("echo 0 > /proc/sys/kernel/randomize_va_space", shell=True)
    # spawn only limited data from parent process
    _mp = multiprocessing.get_context("spawn")

    # init driver
    if d.driver_init() != 0:
        raise SystemExit("driver initialization fail")

    # module fini
    atexit.register(d.driver_fini)
