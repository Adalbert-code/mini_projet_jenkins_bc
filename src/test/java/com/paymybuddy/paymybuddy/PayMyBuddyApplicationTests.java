package com.paymybuddy.paymybuddy;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")  // ← C'est la clé !
class PayMyBuddyApplicationTests {

	@Test
	void contextLoads() {
	}

}
