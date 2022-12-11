import React from "react";
import { Link } from "react-router-dom";
import { useContractReader } from "eth-hooks";
import { ethers } from "ethers";

/**
 * web3 props can be passed from '../App.jsx' into your local view component for use
 * @param {*} yourLocalBalance balance on current network
 * @param {*} readContracts contracts from current chain already pre-loaded using ethers contract module. More here https://docs.ethers.io/v5/api/contract/contract/
 * @returns react component
 */
function Home({ yourLocalBalance, readContracts }) {
  // you can also use hooks locally in your component of choice
  // in this case, let's keep track of 'purpose' variable from our contract
  const purpose = useContractReader(readContracts, "YourContract", "purpose");

  return (
    <div>
      <div style={{ margin: 32 }}>
        <img src="/Judiciary.png" style={{ maxWidth: "500px" }} />
      </div>
      <div style={{ margin: 32, maxWidth: "700px", width: "90%", margin: "auto" }}>
        <p>
          Behind every great company, leader, CEO, Artist, or Creator, is an inspiring journey comprised of moments of
          trials, triumphs and tribulations. I remember early on in my career looking for the coolest people I could
          find brought me to linkedin which showed everyone as a timeline of glorified status symbols- misdirecting my
          ambitious pursuits. What if instead of Harvard degrees and FANG internships, the world saw the process/
          journey of the a person?
        </p>

        <p>
          Imagine a world where 17-year-old Elon Musk documented his journey and the moments he shared with the world
          throughout his life. The second order impact of curated processes will be huge, and early collectors/ people
          tagged in Elon's Judiciarys would be greatly rewarded.
        </p>

        <p>
          Timeless artifacts of historical moments, minted on the permaweb that builds a Judiciary persisting beyond
          oneself. That's what we are building at Judiciary. Enabling passionate humans to become mimentic Storytellers,
          enabling them the serendipity, finacnes, and social capital to prosper.
        </p>

        <p>
          By giving the tools for everyone to document their legacy, we can discover new talent, creators, founders,
          organizations and change their lives just by collecting their moments! Judiciary is bringing economic freedom
          to creators around the world 🚀
        </p>
      </div>
    </div>
  );
}

export default Home;
