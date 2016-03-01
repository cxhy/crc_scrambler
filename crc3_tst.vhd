LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.STD_LOGIC_TEXTIO.ALL;
USE STD.TEXTIO.ALL;

ENTITY crc3_tst IS
END crc3_tst;
ARCHITECTURE crc3_arch OF crc3_tst IS

SIGNAL addr : STD_LOGIC_VECTOR(20 DOWNTO 0);
SIGNAL arst : STD_LOGIC;
SIGNAL clk : STD_LOGIC;
SIGNAL data_in : STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL data_out : STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL in_valid : STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL out_valid : STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL rd : STD_LOGIC;
SIGNAL wr : STD_LOGIC;

SIGNAL matlab_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL rtl_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL compare_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
COMPONENT crc_scrambler
    PORT (
    addr : IN STD_LOGIC_VECTOR(20 DOWNTO 0);
    arst : IN STD_LOGIC;
    clk : IN STD_LOGIC;
    data_in : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    data_out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    in_valid : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    out_valid : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    rtl_out : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    rd : IN STD_LOGIC;
    wr : IN STD_LOGIC
    );
END COMPONENT;
BEGIN
    i1 : crc_scrambler
    PORT MAP (
    addr => addr,
    arst => arst,
    clk => clk,
    data_in => data_in,
    data_out => data_out,
    in_valid => in_valid,
    out_valid => out_valid,
    rtl_out => rtl_out,
    rd => rd,
    wr => wr
    );
init : PROCESS
BEGIN
arst<='0';
WAIT FOR 10us;
arst<='1';
WAIT;
END PROCESS init;


clk_set : PROCESS
BEGIN
clk<='1';
WAIT FOR 5us;
clk<='0';
WAIT FOR 5us;
END PROCESS clk_set;

addr_set :PROCESS
BEGIN
 wr<='1';--首先wr和rd（rd的赋值放在读进程中了）置1，此时既不读也不写
addr<=(others=>'0');
WAIT FOR 20us;
addr<="001001011000011110000";--将控制信号和多项式放入addr，这里前边的“00100”是控制信号（其中高两位的“00”表示模式一这对CRC是没有作用的接着的“1”表示现在选择CRC功能，低两位的“00”输入的数据从高字节到低字节输入，字节中从高位到低位）
WAIT FOR 10us;                --低16位中的高8位“10110000”表示的是多项式，如果多项式多余8位则分周期输入，低8位“11110000”表示多项式“10110000”中的“1011”是有效的其余无效这里的多项式表示的是CRC3：X^3+X+1
addr<="001000000000000000000";--多项式输入完毕后控制位“00100”保持
WAIT FOR 10us;
wr<='0';                      --等多项式输入完毕后wr置0开始输入数据，如果wr未置0而输入端口已经开始输入数据，模块将这些数据视为无效
WAIT;
END PROCESS;

PROCESS(arst,clk)--读进程
FILE data_all:TEXT OPEN READ_MODE IS"data_send.dat";--从matlab产生的文件中读取输入数据
FILE valid_all:TEXT OPEN READ_MODE IS"valid_send.dat"; --从matlab产生的文件中读取输入数据有效位
FILE matlab_all:TEXT OPEN READ_MODE IS"txCRCOut.dat";  --从matlab产生的文件中读取由matlab产生的CRC，用于后边做测试比较
VARIABLE line_in,line_valid,line_matlab:LINE;
VARIABLE valid_temp,matlab_temp:STD_LOGIC;
VARIABLE  data_temp : INTEGER;
VARIABLE cnt:INTEGER:=0;
VARIABLE data_temp_r : STD_LOGIC_VECTOR(7 DOWNTO 0);
BEGIN
IF(arst='0')THEN
  rd<='1';
  data_temp:=0;
  data_temp_r:=(OTHERS=>'0');
  valid_temp:='0';
  matlab_temp:='0';
  matlab_out<=(OTHERS=>'0');
  data_in<=(OTHERS=>'0');
  in_valid<=(OTHERS=>'0');
ELSIF(clk'EVENT AND clk='1')THEN
IF(wr='0')THEN
IF (NOT ENDFILE(data_all))THEN
  FOR i IN 7 DOWNTO 0 LOOP
  READLINE(data_all,line_in);
  READLINE(valid_all,line_valid);
  READ(line_in,data_temp);
  READ(line_valid,valid_temp);
  data_temp_r:=conv_std_logic_vector(data_temp,8);
  data_in(i)<=data_temp_r(i);
  in_valid(i)<=valid_temp;
  IF(valid_temp='0')THEN
  rd<='0';
  END IF;
  END LOOP;
ELSE
  data_in<=(OTHERS=>'0');
  in_valid<=(OTHERS=>'0');
END IF;
IF(cnt=0)THEN
FOR i IN 31 DOWNTO 0 LOOP
IF (NOT ENDFILE(matlab_all))THEN
READLINE(matlab_all,line_matlab);
READ(line_matlab,matlab_temp);
matlab_out(i)<=matlab_temp;--½«ÓÉmatlab²úÉúµÄCRC·ÅÈëmatlab_outÖÐ
ELSE
matlab_out(i)<='0';
END IF;
END LOOP;
cnt:=cnt+1;
END IF;
END IF;
END IF;
END PROCESS;

PROCESS(arst,clk)--Ð´½ø³Ì
FILE out_all:TEXT OPEN WRITE_MODE IS"data_out.txt";
VARIABLE zero:STD_LOGIC_VECTOR(7 DOWNTO 0):=(OTHERS=>'0');
VARIABLE line_out:LINE;
VARIABLE out_temp:STD_LOGIC_VECTOR(7 DOWNTO 0);
BEGIN
IF(arst='0')THEN
out_temp:=(OTHERS=>'0');
ELSIF(clk'EVENT AND clk='1')THEN
     IF(out_valid/=zero)THEN
       FOR i IN 7 DOWNTO 0 LOOP
          IF(out_valid(i)='1')THEN
             out_temp(i):=data_out(i);
            ELSE
               out_temp(i):='Z';
            END IF;
        END LOOP;
       WRITE(line_out,out_temp);
       WRITELINE(out_all,line_out);
     END IF;
END IF;
END PROCESS;

PROCESS(arst,clk)
VARIABLE cnt1:INTEGER:=0;
BEGIN
IF(arst='0')THEN
compare_out<=(OTHERS=>'0');
ELSIF(clk'EVENT AND clk='1')THEN
     compare_out<=matlab_out XOR rtl_out;--½«ÓÉmatlab²úÉúµÄCRCÓëRTL²úÉúµÄCRC×öÒì»ò
     IF(rd='0')THEN
      cnt1:=cnt1+1;
      END IF;
      IF(cnt1=3)THEN
        IF(compare_out="00000000000000000000000000000000")THEN--Èç¹ûÒì»òÖµÈ«Îª0ËµÃ÷Á©ÕßÏàÍ¬£¬RTLÕýÈ·
         REPORT"OK!";
         ELSE
         REPORT"WRONG!"--Èç¹ûÒì»òÖµ²»È«Îª0ËµÃ÷Á©¸öCRC²»ÏàÍ¬£¬RTL´íÎó²¢·¢³ö´íÎóµÈ¼¶
         SEVERITY ERROR;
         END IF;
      END IF;
END IF;
END PROCESS;

END crc3_arch;

--LIBRARY IEEE;
--USE IEEE.STD_LOGIC_1164.ALL;
--USE IEEE.STD_LOGIC_TEXTIO.ALL;
--USE STD.TEXTIO.ALL;

--ENTITY crc3_tst IS
--END crc3_tst;
--ARCHITECTURE crc3_arch OF crc3_tst IS

--SIGNAL addr : STD_LOGIC_VECTOR(20 DOWNTO 0);
--SIGNAL arst : STD_LOGIC;
--SIGNAL clk : STD_LOGIC;
--SIGNAL data_in : STD_LOGIC_VECTOR(7 DOWNTO 0);
--SIGNAL data_out : STD_LOGIC_VECTOR(7 DOWNTO 0);
--SIGNAL in_valid : STD_LOGIC_VECTOR(7 DOWNTO 0);
--SIGNAL out_valid : STD_LOGIC_VECTOR(7 DOWNTO 0);
--SIGNAL rd : STD_LOGIC;
--SIGNAL wr : STD_LOGIC;

--SIGNAL matlab_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
--SIGNAL rtl_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
--SIGNAL compare_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
--COMPONENT crc_scrambler
--  PORT (
--  addr : IN STD_LOGIC_VECTOR(20 DOWNTO 0);
--  arst : IN STD_LOGIC;
--  clk : IN STD_LOGIC;
--  data_in : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
--  data_out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
--  in_valid : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
--  out_valid : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
--  rtl_out : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
--  rd : IN STD_LOGIC;
--  wr : IN STD_LOGIC
--  );
--END COMPONENT;
--BEGIN
--  i1 : crc_scrambler
--  PORT MAP (
--  addr => addr,
--  arst => arst,
--  clk => clk,
--  data_in => data_in,
--  data_out => data_out,
--  in_valid => in_valid,
--  out_valid => out_valid,
--  rtl_out => rtl_out,
--  rd => rd,
--  wr => wr
--  );
--init : PROCESS
--BEGIN
--arst<='0';
--WAIT FOR 10us;
--arst<='1';
--WAIT;
--END PROCESS init;


--clk_set : PROCESS
--BEGIN
--clk<='1';
--WAIT FOR 5us;
--clk<='0';
--WAIT FOR 5us;
--END PROCESS clk_set;

--addr_set :PROCESS
--BEGIN
-- wr<='1';--首先wr和rd（rd的赋值放在读进程中了）置1，此时既不读也不写
--addr<=(others=>'0');
--WAIT FOR 20us;
--addr<="001001011000011110000";--将控制信号和多项式放入addr，这里前边的“00100”是控制信号（其中高两位的“00”表示模式一这对CRC是没有作用的接着的“1”表示现在选择CRC功能，低两位的“00”输入的数据从高字节到低字节输入，字节中从高位到低位）
--WAIT FOR 10us;                --低16位中的高8位“10110000”表示的是多项式，如果多项式多余8位则分周期输入，低8位“11110000”表示多项式“10110000”中的“1011”是有效的其余无效这里的多项式表示的是CRC3：X^3+X+1
--addr<="001000000000000000000";--多项式输入完毕后控制位“00100”保持
--WAIT FOR 10us;
--wr<='0';                      --等多项式输入完毕后wr置0开始输入数据，如果wr未置0而输入端口已经开始输入数据，模块将这些数据视为无效
--WAIT;
--END PROCESS;


--PROCESS(arst,clk)--读进程
--FILE data_all:TEXT OPEN READ_MODE IS"data_send.dat";--从matlab产生的文件中读取输入数据
--FILE valid_all:TEXT OPEN READ_MODE IS"valid_send.dat"; --从matlab产生的文件中读取输入数据有效位
--FILE matlab_all:TEXT OPEN READ_MODE IS"txCRCOut.dat";  --从matlab产生的文件中读取由matlab产生的CRC，用于后边做测试比较
--VARIABLE line_in,line_valid,line_matlab:LINE;
--VARIABLE data_temp,valid_temp,matlab_temp:STD_LOGIC;
--VARIABLE cnt:INTEGER:=0;
--BEGIN
--IF(arst='0')THEN
--  rd<='1';
--  data_temp:='0';
--  valid_temp:='0';
--  matlab_temp:='0';
--  matlab_out<=(OTHERS=>'0');
--  data_in<=(OTHERS=>'0');
--  in_valid<=(OTHERS=>'0');
--ELSIF(clk'EVENT AND clk='1')THEN
--IF(wr='0')THEN
--IF (NOT ENDFILE(data_all))THEN
--  FOR i IN 7 DOWNTO 0 LOOP
--  READLINE(data_all,line_in);
--  READLINE(valid_all,line_valid);
--  READ(line_in,data_temp);
--  READ(line_valid,valid_temp);
--  data_in(i)<=data_temp;
--  in_valid(i)<=valid_temp;
--  IF(valid_temp='0')THEN
--  rd<='0';
--  END IF;
--  END LOOP;
--ELSE
--  data_in<=(OTHERS=>'0');
--  in_valid<=(OTHERS=>'0');
--END IF;
--IF(cnt=0)THEN
--FOR i IN 31 DOWNTO 0 LOOP
--IF (NOT ENDFILE(matlab_all))THEN
--READLINE(matlab_all,line_matlab);
--READ(line_matlab,matlab_temp);
--matlab_out(i)<=matlab_temp;--将由matlab产生的CRC放入matlab_out中
--ELSE
--matlab_out(i)<='0';
--END IF;
--END LOOP;
--cnt:=cnt+1;
--END IF;
--END IF;
--END IF;
--END PROCESS;

--PROCESS(arst,clk)--写进程
--FILE out_all:TEXT OPEN WRITE_MODE IS"data_out.txt";
--VARIABLE zero:STD_LOGIC_VECTOR(7 DOWNTO 0):=(OTHERS=>'0');
--VARIABLE line_out:LINE;
--VARIABLE out_temp:STD_LOGIC_VECTOR(7 DOWNTO 0);
--BEGIN
--IF(arst='0')THEN
--out_temp:=(OTHERS=>'0');
--ELSIF(clk'EVENT AND clk='1')THEN
--     IF(out_valid/=zero)THEN
--       FOR i IN 7 DOWNTO 0 LOOP
--          IF(out_valid(i)='1')THEN
--             out_temp(i):=data_out(i);
--          ELSE
--             out_temp(i):='Z';
--          END IF;
--      END LOOP;
--       WRITE(line_out,out_temp);
--       WRITELINE(out_all,line_out);
--     END IF;
--END IF;
--END PROCESS;

--PROCESS(arst,clk)
--VARIABLE cnt1:INTEGER:=0;
--BEGIN
--IF(arst='0')THEN
--compare_out<=(OTHERS=>'0');
--ELSIF(clk'EVENT AND clk='1')THEN
--     compare_out<=matlab_out XOR rtl_out;--将由matlab产生的CRC与RTL产生的CRC做异或
--     IF(rd='0')THEN
--    cnt1:=cnt1+1;
--    END IF;
--    IF(cnt1=3)THEN
--      IF(compare_out="00000000000000000000000000000000")THEN--如果异或值全为0说明俩者相同，RTL正确
--       REPORT"OK!";
--       ELSE
--       REPORT"WRONG!"--如果异或值不全为0说明俩个CRC不相同，RTL错误并发出错误等级
--       SEVERITY ERROR;
--       END IF;
--    END IF;
--END IF;
--END PROCESS;

--END crc3_arch;
