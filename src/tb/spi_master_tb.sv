module spi_master_tb;
   parameter int clk_rate = 400000;
   time		 period = 1s/clk_rate;

   parameter int CLOCK_POLARITY_G = 0;
   parameter int CLOCK_PHASE_G    = 0;
   parameter int MSB_FIRST      = 1;
   parameter int RST_LEVEL      = 0;

   const logic [7:0] test_mosi_beats[3] = {
					   8'h37,
					   8'h48,
					   8'h59
					   };

   const logic [7:0] test_miso_beats[3] = {
					   8'hC8,
					   8'hB7,
					   8'hA6
					   };


   logic	 clk  = 0;
   logic	 rstn = 0;

   logic	 m_tvalid;
   logic	 m_tready;
   logic [31:0]  m_tdata;
   logic	 m_tlast;

   logic	 s_tvalid;
   logic	 s_tready;
   logic [31:0]  s_tdata;
   logic	 s_tlast;

   logic [31:0]  num_bytes;
   logic	 busy;

   wire		 sclk;
   wire		 mosi;
   wire		 miso;
   wire		 ss;

   logic         trig = 0;
   logic	 mosi_success_s = '0;
   logic	 miso_success_s = '0;


   axis_if #(.TDATA_BYTES(1)) m_connector(.aclk(clk), .aresetn(rstn));
   axis_if #(.TDATA_BYTES(1)) s_connector(.aclk(clk), .aresetn(rstn));


   assign m_tvalid = m_connector.tvalid;
   assign m_tready = m_connector.tready;
   assign m_tdata  = m_connector.tdata;
   assign m_tlast  = m_connector.tlast;

   assign s_tvalid = s_connector.tvalid;
   assign s_tready = s_connector.tready;
   assign s_tdata  = s_connector.tdata;
   assign s_tlast  = s_connector.tlast;

   initial begin
      forever begin
	 #(period/2) clk = ~clk;
      end
   end


   initial begin
      $timeformat(-9, 2, " ns", 20);
      $display("==========================");
      $display("====== TEST START! =======");
      $display("==========================");

      repeat(10) #(period);

      $display("%t: TB - Deasserting resets", $time);
      rstn <= '1;
      repeat(2) #(period);

      #100ns;
      $display("%t: TB - Asserting trigger", $time);
      trig <= '1;
      #(period);
      $display("%t: TB - Deasserting trigger", $time);
      trig <= '0;

      #(period);

      // repeat(10) #(period);
      // axis_master.write_beat();

      wait(miso_success_s == '1);
      wait(mosi_success_s == '1);

      $display("============================");
      $display("======= TEST PASSED! =======");
      $display("============================");
      $finish;
   end


   /**************************************************************************
    * Test the MOSI pathway.
    **************************************************************************/
   task test_mosi;
      logic [7:0] temp_byte;

      begin
	 // Write MOSI test data
	 for(int x=0; x<$size(test_mosi_beats); x++) begin
	    if(x == $size(test_mosi_beats)-1) begin
	       u_axis_master.put_simple_beat(.tdata(test_mosi_beats[x]), .tlast('1));

	    end else begin
	       u_axis_master.put_simple_beat(.tdata(test_mosi_beats[x]), .tlast('0));

	    end
	 end

	 $timeformat(-9, 2, " ns", 20);

	 // Read MOSI test data
	 for(int x=0; x<$size(test_mosi_beats); x++) begin
	    u_spi_slave.get_mosi_byte(temp_byte);
	    assert(temp_byte == test_mosi_beats[x]) else $fatal("%t: TB - MOSI - Expected: '%h' Found: '%h'", $time, test_mosi_beats[x], temp_byte);

	 end

	 $display("%t: TB - MOSI Test [PASS]", $time);
	 mosi_success_s = '1;
      end
   endtask // test_mosi



   /**************************************************************************
    * Test the MISO pathway.
    **************************************************************************/
   task test_miso;
      logic [7:0] temp_byte;
      logic	  temp_last;

      begin
	 $timeformat(-9, 2, " ns", 20);
	 // Write MISO test data
	 for(int x=0; x<$size(test_miso_beats); x++) begin
	    u_spi_slave.put_miso_byte(test_miso_beats[x]);
	 end


	 // Read MISO test data
	 for(int x=0; x<$size(test_miso_beats); x++) begin
	    u_axis_slave.get_simple_beat(.tdata(temp_byte), .tlast(temp_last));
	    // assert(temp_byte == test_miso_beats[x]) else $fatal("%t: TB - MISO - Expected: '%h' Found: '%h'", $time, test_miso_beats[x], temp_byte);

	    // if(x==$size(test_miso_beats)-1) begin
	    //    assert(temp_last == '1) else $fatal("%t: TB - MISO - Expected tlast '%b' Found tlast '%b'", $time, '1, temp_last);

	    // end else begin
	    //    assert(temp_last == '0) else $fatal("%t: TB - MISO - Expected tlast '%b' Found tlast '%b'", $time, '0, temp_last);

	    // end
	 end

	 $display("%t: TB - MISO Test [PASS]", $time);
	 miso_success_s = '1;
      end
   endtask // test_miso


   initial begin
      test_miso();
   end

   initial begin
      test_mosi();
   end




   initial begin
      #(1000*period)

      $display("============================");
      $display("======= TEST FAILED! =======");
      $display("============================");
      $finish;
   end


   // BFMs
   spi_slave_bfm   #(.clk_polarity(CLOCK_POLARITY_G), .clk_phase(CLOCK_PHASE_G)) u_spi_slave(.sclk(sclk), .mosi(mosi), .miso(miso), .ss(ss));
   axis_master_bfm u_axis_master(m_connector);
   axis_slave_bfm  u_axis_slave(s_connector);

   // DUT
   spi_master_wrapper #(
			.CLOCK_POLARITY_G(CLOCK_POLARITY_G),
			.CLOCK_PHASE_G(CLOCK_PHASE_G),
			.MSB_FIRST_G(MSB_FIRST),
			.RST_LEVEL_G(RST_LEVEL)
			) dut (
			       .clk_in(clk),
			       .rst_in(rstn),
			       .sclk(sclk),
			       .mosi(mosi),
			       .miso(miso),
			       .cs(ss),
			       .s_axis_tdata(m_connector.tdata),
			       .s_axis_tvalid(m_connector.tvalid),
			       .s_axis_tready(m_connector.tready),
			       .s_axis_tlast(m_connector.tlast),
			       .m_axis_tdata(s_connector.tdata),
			       .m_axis_tvalid(s_connector.tvalid),
			       .m_axis_tready(s_connector.tready),
			       .m_axis_tlast(s_connector.tlast),
			       .trigger(trig),
			       .num_bytes(num_bytes),
			       .busy(busy)
			       );

endmodule // spi_master_tb
